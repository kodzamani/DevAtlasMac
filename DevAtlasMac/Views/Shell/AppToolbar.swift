import SwiftUI

/// Window toolbar: history navigation on the leading side, contextual controls on the trailing side.
struct AppToolbar: ToolbarContent {
    @Bindable var viewModel: AppViewModel
    @Bindable var statsVM: StatsViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("finder.back".localized, systemImage: "chevron.left") {
                viewModel.navigateBack()
            }
            .disabled(!viewModel.canNavigateBack)
            .keyboardShortcut("[", modifiers: .command)
            .help("finder.back".localized)

            Button("finder.forward".localized, systemImage: "chevron.right") {
                viewModel.navigateForward()
            }
            .disabled(!viewModel.canNavigateForward)
            .keyboardShortcut("]", modifiers: .command)
            .help("finder.forward".localized)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            switch viewModel.selectedTab {
            case .atlas where !viewModel.isShowingDetail:
                browserControls
            case .notebook:
                notebookScopeMenu
            case .stats:
                statsControls
            default:
                EmptyView()
            }

            Button("sidebar.darkMode".localized, systemImage: viewModel.isDarkMode ? "sun.max" : "moon") {
                viewModel.isDarkMode.toggle()
            }
            .help("sidebar.darkMode".localized)
        }
    }

    // MARK: - Atlas

    @ViewBuilder
    private var browserControls: some View {
        Picker("finder.viewMode".localized, selection: $viewModel.viewMode) {
            ForEach(BrowserViewMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .help("finder.viewMode".localized)

        Button("sidebar.scanProjects".localized, systemImage: "wand.and.rays") {
            Task { await viewModel.startScan() }
        }
        .disabled(viewModel.scanProgress.isScanning)
        .help("sidebar.scanProjects".localized)

        Menu("finder.actions".localized, systemImage: "ellipsis.circle") {
            if let project = viewModel.highlightedProject {
                ProjectContextMenu(viewModel: viewModel, project: project)
            }
        }
        .disabled(viewModel.highlightedProject == nil)
        .help("finder.actions".localized)

        if viewModel.viewMode != .columns {
            Button("finder.togglePreview".localized, systemImage: "sidebar.trailing") {
                viewModel.isPreviewPaneVisible.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .help("finder.togglePreview".localized)
        }
    }

    // MARK: - Notebook

    private var notebookScopeMenu: some View {
        Menu(viewModel.notebookSearchScope.displayText) {
            Button("notebook.allNotes".localized) { viewModel.notebookSearchScope = .allNotes }
            Button("notebook.currentProject".localized) { viewModel.notebookSearchScope = .currentProject }
            Button("notebook.withinContent".localized) { viewModel.notebookSearchScope = .contentOnly }
            Button("notebook.byCategoryTags".localized) { viewModel.notebookSearchScope = .byTags }
        }
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsControls: some View {
        Menu("nav.export".localized, systemImage: "square.and.arrow.up") {
            Button("notebook.exportAsCsv".localized) { statsVM.exportAsCSV() }
        }

        Menu(statsVM.dateRange.rawValue) {
            ForEach(DateRangeFilter.allCases) { range in
                Toggle(range.rawValue, isOn: Binding(
                    get: { statsVM.dateRange == range },
                    set: { if $0 { statsVM.dateRange = range } }
                ))
            }
        }
    }
}
