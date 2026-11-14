import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: AppViewModel
    let notebookVM: NotebookViewModel
    let statsVM: StatsViewModel
    let cacheVM: ProjectCacheViewModel
    let chatVM: ChatViewModel
    @State private var onboardingVM = OnboardingViewModel()
    @State private var languageManager = LanguageManager()
    @State private var isSearchPresented = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Force refresh for language changes
    @State private var languageRefreshTrigger: Int = 0

    var body: some View {
        ZStack {
            // Rendered instead of the main content so the window toolbar goes away with it.
            if onboardingVM.isPresented {
                OnboardingContainerView(viewModel: onboardingVM)
                    .environment(viewModel)
                    .environment(languageManager)
                    .navigationTitle("")
                    .toolbarBackground(.hidden, for: .windowToolbar)
                    .transition(.opacity)
            } else {
                mainContent
            }
        }
        .frame(minWidth: 1080, minHeight: 600)
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
        .task {
            await viewModel.loadInitialData()
            await notebookVM.loadNotes()
            // Warm the stats so the tab opens with its data already in place.
            statsVM.projectsDidChange(viewModel.filteredProjects)
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingVM.isPresented)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            languageRefreshTrigger += 1
            viewModel.languageRevision += 1
        }
        .id(languageRefreshTrigger)
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AppSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            ZStack {
                AuroraBackground()

                HStack(spacing: 0) {
                    switch viewModel.selectedTab {
                    case .atlas:
                        atlasContent
                    case .chat:
                        ChatContentView(viewModel: viewModel, chatVM: chatVM)
                    case .stats:
                        statsLayout
                    case .ports:
                        PortProcessContentView(viewModel: viewModel)
                    case .projectCache:
                        ProjectCacheContentView(viewModel: viewModel, cacheVM: cacheVM)
                    case .notebook:
                        notebookLayout
                    case .aiPrompts:
                        AIPromptsContentView()
                    case .settings:
                        settingsLayout
                    }
                }
            }
            .modifier(ToolbarSearchModifier(
                isEnabled: viewModel.selectedTab != .chat,
                text: $viewModel.searchText,
                isPresented: $isSearchPresented,
                prompt: viewModel.selectedTab == .ports ? "ports.search".localized : (viewModel.selectedTab == .notebook ? "search.notes".localized : "search.projects".localized)
            ))
            .navigationTitle(viewModel.selectedTab == .chat ? "" : viewModel.windowTitle)
            .toolbar {
                AppToolbar(viewModel: viewModel, statsVM: statsVM, cacheVM: cacheVM, chatVM: chatVM)
            }
        }
        .tint(Color.daAccent)
        .onChange(of: viewModel.currentLocation, initial: true) {
            viewModel.recordLocationChange()
        }
        .keyboardShortcut(KeyEquivalent("p"), modifiers: .command, action: {
            isSearchPresented = true
        })
        .keyboardShortcut(KeyEquivalent("f"), modifiers: .command, action: {
            isSearchPresented = true
        })
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotebookNotesUpdated"))) { _ in
            Task {
                await notebookVM.loadNotes()
            }
        }
        .onChange(of: viewModel.pendingNavigateToNoteId) { oldValue, newValue in
            if let noteId = newValue, oldValue != newValue {
                // Switch to notebook tab
                viewModel.selectedTab = .notebook
                
                // Close the project detail view if open
                if viewModel.isShowingDetail {
                    viewModel.goBack()
                }
                
                // Reload notes and select the saved note
                Task {
                    await notebookVM.loadNotes()
                    
                    // Wait a brief moment for notes to load, then select
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    
                    await MainActor.run {
                        if let note = notebookVM.notes.first(where: { $0.id == noteId }) {
                            notebookVM.selectedNote = note
                        }
                        // Clear the pending navigation
                        viewModel.pendingNavigateToNoteId = nil
                    }
                }
            }
        }
    }

    // MARK: - Atlas Content
    private var atlasContent: some View {
        VStack(spacing: 0) {
            if viewModel.scanProgress.isScanning {
                ScanStatusStrip(progress: viewModel.scanProgress)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                if viewModel.isShowingDetail, let project = viewModel.selectedProject {
                    ProjectDetailView(viewModel: viewModel, project: project)
                        .id(project.id)
                        .transition(.opacity)
                } else {
                    ProjectBrowserView(viewModel: viewModel) {
                        onboardingVM.showOnboarding()
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.isShowingDetail)
        .animation(.easeInOut(duration: 0.2), value: viewModel.scanProgress.isScanning)
    }

    // MARK: - Stats Layout
    private var statsLayout: some View {
        StatsContentView(viewModel: viewModel, statsVM: statsVM)
    }

    // MARK: - Notebook Layout
    private var notebookLayout: some View {
        Group {
            NotebookSidebarView(viewModel: viewModel, notebookVM: notebookVM)
            NotebookContentView(notebookVM: notebookVM, viewModel: viewModel)
        }
    }
    
    // MARK: - Settings Layout
    private var settingsLayout: some View {
        SettingsContentView(languageManager: languageManager)
            .environment(viewModel)
    }
}

#Preview {
    let appVM = AppViewModel()
    return ContentView(viewModel: appVM, notebookVM: NotebookViewModel(), statsVM: StatsViewModel(), cacheVM: ProjectCacheViewModel(), chatVM: ChatViewModel(appViewModel: appVM))
}


/// Adds the toolbar search field, except on screens that have nothing to search (Chat).
private struct ToolbarSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String
    @Binding var isPresented: Bool
    let prompt: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $text, isPresented: $isPresented, placement: .toolbar, prompt: prompt)
        } else {
            content
        }
    }
}
