import SwiftUI

/// macOS 13+ gets the full app (menu bar extra included); macOS 12 gets a plain window.
@main
enum AppLauncher {
    static func main() {
        if #available(macOS 13.0, *) {
            DevAtlasMacApp.main()
        } else {
            LegacyDevAtlasApp.main()
        }
    }
}

/// True where the menu bar extra exists (macOS 13+). Without it the app lives and dies with its window.
let appHasMenuBarExtra: Bool = {
    if #available(macOS 13.0, *) { return true }
    return false
}()

/// Monterey: a single window, no menu bar extra.
struct LegacyDevAtlasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: AppViewModel
    @StateObject private var notebookVM = NotebookViewModel()
    @StateObject private var statsVM = StatsViewModel()
    @StateObject private var cacheVM = ProjectCacheViewModel()
    @StateObject private var chatVM: ChatViewModel

    init() {
        let viewModel = AppViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        _chatVM = StateObject(wrappedValue: ChatViewModel(appViewModel: viewModel))
        QuickSearchController.shared.configure(viewModel: viewModel)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, notebookVM: notebookVM, statsVM: statsVM, cacheVM: cacheVM, chatVM: chatVM)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

@available(macOS 13.0, *)
struct DevAtlasMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Held here so they outlive the window: the menu bar keeps working while it is closed,
    // and reopening picks up where the user left off.
    @StateObject private var viewModel: AppViewModel
    @StateObject private var notebookVM = NotebookViewModel()
    @StateObject private var statsVM = StatsViewModel()
    @StateObject private var cacheVM = ProjectCacheViewModel()
    @StateObject private var chatVM: ChatViewModel

    init() {
        let viewModel = AppViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        _chatVM = StateObject(wrappedValue: ChatViewModel(appViewModel: viewModel))
        QuickSearchController.shared.configure(viewModel: viewModel)
        // The menu bar needs the projects even if no window opens at launch.
        Task { await viewModel.loadInitialData() }
    }

    var body: some Scene {
        Window("DevAtlas", id: MenuBarContent.mainWindowID) {
            ContentView(viewModel: viewModel, notebookVM: notebookVM, statsVM: statsVM, cacheVM: cacheVM, chatVM: chatVM)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1440, height: 900)

        MenuBarExtra {
            MenuBarContent(viewModel: viewModel)
        } label: {
            MenuBarLabel()
                .task {
                    while !Task.isCancelled {
                        async let ports: Void = viewModel.portManager.refresh()
                        async let docker: Void = viewModel.dockerManager.refresh(projects: viewModel.projects)
                        _ = await (ports, docker)
                        do { try await Task.sleep(nanoseconds: UInt64(10 * 1_000_000_000)) }
                        catch { return }
                    }
                }
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The menu bar icon. Always on screen, so it hands the quick search panel a way to open the
/// main window even while that window is closed.
@available(macOS 13.0, *)
private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image("menubar_logo")
            .onAppear {
                QuickSearchController.shared.openMainWindow = {
                    openWindow(id: MenuBarContent.mainWindowID)
                }
            }
    }
}
