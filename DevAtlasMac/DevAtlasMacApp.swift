import SwiftUI

@main
struct DevAtlasMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Held here so they outlive the window: the menu bar keeps working while it is closed,
    // and reopening picks up where the user left off.
    @State private var viewModel: AppViewModel
    @State private var notebookVM = NotebookViewModel()
    @State private var statsVM = StatsViewModel()
    @State private var cacheVM = ProjectCacheViewModel()
    @State private var chatVM: ChatViewModel

    init() {
        let viewModel = AppViewModel()
        _viewModel = State(initialValue: viewModel)
        _chatVM = State(initialValue: ChatViewModel(appViewModel: viewModel))
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
                        await viewModel.portManager.refresh()
                        do { try await Task.sleep(for: .seconds(10)) }
                        catch { return }
                    }
                }
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The menu bar icon. Always on screen, so it hands the quick search panel a way to open the
/// main window even while that window is closed.
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
