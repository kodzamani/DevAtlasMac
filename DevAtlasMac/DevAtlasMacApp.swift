import SwiftUI

@main
struct DevAtlasMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Held here so they outlive the window: the menu bar keeps working while it is closed,
    // and reopening picks up where the user left off.
    @State private var viewModel: AppViewModel
    @State private var notebookVM = NotebookViewModel()
    @State private var statsVM = StatsViewModel()

    init() {
        let viewModel = AppViewModel()
        _viewModel = State(initialValue: viewModel)
        // The menu bar needs the projects even if no window opens at launch.
        Task { await viewModel.loadInitialData() }
    }

    var body: some Scene {
        Window("DevAtlas", id: MenuBarContent.mainWindowID) {
            ContentView(viewModel: viewModel, notebookVM: notebookVM, statsVM: statsVM)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1440, height: 900)

        MenuBarExtra {
            MenuBarContent(viewModel: viewModel)
        } label: {
            Image("menubar_logo")
        }
        .menuBarExtraStyle(.menu)
    }
}
