import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var notebookVM = NotebookViewModel()
    @State private var statsVM = StatsViewModel()
    @State private var onboardingVM = OnboardingViewModel()
    @State private var languageManager = LanguageManager()
    @FocusState private var isSearchFocused: Bool
    
    // Force refresh for language changes
    @State private var languageRefreshTrigger: Int = 0

    var body: some View {
        ZStack {
            mainContent
            
            // Onboarding Overlay
            if onboardingVM.isPresented {
                OnboardingContainerView(viewModel: onboardingVM)
                    .environment(viewModel)
                    .environment(languageManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingVM.isPresented)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            languageRefreshTrigger += 1
        }
        .id(languageRefreshTrigger)
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            TopNavigationBar(viewModel: viewModel, notebookVM: notebookVM, statsVM: statsVM, isSearchFocused: $isSearchFocused)

            HStack(spacing: 0) {
                SidebarView(viewModel: viewModel)

                Group {
                    switch viewModel.selectedTab {
                    case .atlas:
                        atlasContent
                    case .stats:
                        statsLayout
                    case .notebook:
                        notebookLayout
                    case .aiPrompts:
                        AIPromptsContentView()
                    case .settings:
                        settingsLayout
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTab)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .id(viewModel.isDarkMode)
        .frame(minWidth: 1080, minHeight: 600)
        .background(Color.daOffWhite)
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
        .task {
            await viewModel.loadInitialData()
            await notebookVM.loadNotes()
        }
        .keyboardShortcut(KeyEquivalent("p"), modifiers: .command, action: {
            isSearchFocused = true
        })
        .onKeyPress(.init("p"), phases: .down) { _ in
            if NSEvent.modifierFlags.contains(.command) {
                isSearchFocused = true
                return .handled
            }
            return .ignored
        }
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
        ZStack {
            if viewModel.isShowingDetail, let project = viewModel.selectedProject {
                ProjectDetailView(viewModel: viewModel, project: project)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ProjectListView(viewModel: viewModel) {
                    onboardingVM.showOnboarding()
                }
                .transition(.opacity)
            }

            if viewModel.scanProgress.isScanning {
                ScanningOverlay(progress: viewModel.scanProgress)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isShowingDetail)
        .animation(.easeInOut(duration: 0.3), value: viewModel.scanProgress.isScanning)
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
    ContentView()
}
