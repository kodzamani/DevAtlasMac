import SwiftUI
import Observation

@Observable
final class AppViewModel {
    // MARK: - State
    var projects: [ProjectInfo] = []
    var filteredProjects: [ProjectInfo] = []
    var searchText: String = "" {
        didSet {
            if isShowingDetail { goBack() }
            applyFilters()
        }
    }
    var selectedCategory: String = "All" {
        didSet {
            if isShowingDetail { goBack() }
            applyFilters()
        }
    }
    var selectedTag: String? {
        didSet {
            if isShowingDetail { goBack() }
            applyFilters()
        }
    }
    var viewMode: BrowserViewMode = BrowserViewMode(rawValue: UserDefaults.standard.string(forKey: "browserViewMode") ?? "") ?? .icons {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "browserViewMode") }
    }
    var isPreviewPaneVisible: Bool = UserDefaults.standard.object(forKey: "browserPreviewPaneVisible") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isPreviewPaneVisible, forKey: "browserPreviewPaneVisible") }
    }
    /// The project selected in the browser. Opening it is a separate step, as in Finder.
    var highlightedProjectID: String?
    var scanProgress = ScanProgress()
    var selectedProject: ProjectInfo?
    var isShowingDetail: Bool = false
    /// The open project page has stepped into its code analysis.
    var isShowingProjectAnalysis: Bool = false
    var isDarkMode: Bool = UserDefaults.standard.bool(forKey: "isDarkMode") {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    var selectedTab: AppTab = .atlas
    var notebookSearchScope: NotebookSearchScope = .allNotes
    
    // Navigation to notebook
    var pendingNavigateToNoteId: String?

    // MARK: - Stats
    private var statsTask: Task<Void, Never>?
    /// Projects whose persisted counts were already re-checked during this launch.
    private var refreshedCountIDs: Set<String> = []
    var filteredTotalFiles: Int = 0
    var filteredTotalLines: Int = 0
    var isCalculatingStats: Bool = false

    // MARK: - Services
    private let scanner = ProjectScanner()
    private let index = ProjectIndex()
    let runner = ProjectRunner()

    // MARK: - Category Counts
    var allCount: Int { projects.count }
    var webCount: Int { projects.filter { $0.category == .web }.count }
    var desktopCount: Int { projects.filter { $0.category == .desktop }.count }
    var mobileCount: Int { projects.filter { $0.category == .mobile }.count }
    var cloudCount: Int { projects.filter { $0.category == .cloud }.count }

    /// The most used tags, shown in the sidebar like Finder's tags.
    var topTags: [String] {
        let counts = Dictionary(projects.flatMap(\.tags).map { ($0, 1) }, uniquingKeysWith: +)
        return counts
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(6)
            .map(\.key)
    }

    var highlightedProject: ProjectInfo? {
        guard let highlightedProjectID else { return nil }
        return filteredProjects.first { $0.id == highlightedProjectID }
    }

    // MARK: - Sidebar

    var sidebarSelection: SidebarDestination? {
        get {
            if selectedTab != .atlas { return .tab(selectedTab) }
            if let selectedTag { return .tag(selectedTag) }
            return .category(selectedCategory)
        }
        set {
            switch newValue {
            case .category(let category):
                selectedTab = .atlas
                if selectedTag != nil { selectedTag = nil }
                selectedCategory = category
            case .tag(let tag):
                selectedTab = .atlas
                selectedCategory = "All"
                selectedTag = tag
            case .tab(let tab):
                selectedTab = tab
            case nil:
                break
            }
        }
    }

    /// The current place, as shown in the window title and the path bar.
    var locationTitle: String {
        if let selectedTag { return selectedTag }
        switch selectedCategory {
        case "All": return "sidebar.allProjects".localized
        case "Web": return "sidebar.web".localized
        case "Desktop": return "sidebar.desktop".localized
        case "Mobile": return "sidebar.mobile".localized
        case "Cloud": return "sidebar.cloud".localized
        default: return selectedCategory
        }
    }

    var windowTitle: String {
        switch selectedTab {
        case .atlas: return isShowingDetail ? (selectedProject?.name ?? locationTitle) : locationTitle
        case .stats: return "tab.stats".localized
        case .notebook: return "tab.notebook".localized
        case .aiPrompts: return "tab.aiPrompts".localized
        case .settings: return "tab.settings".localized
        }
    }

    // MARK: - History

    private var backStack: [BrowserLocation] = []
    private var forwardStack: [BrowserLocation] = []
    private var recordedLocation: BrowserLocation?

    var canNavigateBack: Bool { !backStack.isEmpty }
    var canNavigateForward: Bool { !forwardStack.isEmpty }

    var currentLocation: BrowserLocation {
        BrowserLocation(
            tab: selectedTab,
            category: selectedCategory,
            tag: selectedTag,
            projectID: isShowingDetail ? selectedProject?.id : nil,
            isAnalyzingProject: isShowingDetail && isShowingProjectAnalysis
        )
    }

    /// Adds the current location to the history if it changed since the last call.
    func recordLocationChange() {
        let location = currentLocation
        guard let previous = recordedLocation else {
            recordedLocation = location
            return
        }
        guard previous != location else { return }
        backStack.append(previous)
        if backStack.count > 50 { backStack.removeFirst() }
        forwardStack.removeAll()
        recordedLocation = location
    }

    func navigateBack() {
        guard let target = backStack.popLast() else { return }
        forwardStack.append(currentLocation)
        restore(target)
    }

    func navigateForward() {
        guard let target = forwardStack.popLast() else { return }
        backStack.append(currentLocation)
        restore(target)
    }

    private func restore(_ location: BrowserLocation) {
        selectedTab = location.tab
        if selectedCategory != location.category { selectedCategory = location.category }
        if selectedTag != location.tag { selectedTag = location.tag }

        if let id = location.projectID, let project = projects.first(where: { $0.id == id }) {
            selectProject(project)
            isShowingProjectAnalysis = location.isAnalyzingProject
        } else {
            goBack()
        }
        recordedLocation = currentLocation
    }

    // MARK: - Initialization

    func loadInitialData() async {
        var cached = await index.loadProjects()
        
        // Filter out excluded paths from cached projects
        let languageManager = LanguageManager()
        let excludedPaths = languageManager.excludedPaths
            .map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL.path }
        if !excludedPaths.isEmpty {
            cached = cached.filter { project in
                let projectPath = URL(fileURLWithPath: project.path)
                    .resolvingSymlinksInPath()
                    .standardizedFileURL
                    .path
                return !excludedPaths.contains { excludedPath in
                    projectPath == excludedPath || projectPath.hasPrefix(excludedPath + "/")
                }
            }
        }
        
        if !cached.isEmpty {
            await MainActor.run {
                self.projects = deduplicatedByPath(cached)
                self.applyFilters()
            }
        }

        let needsRescan = await index.needsRescan()
        if cached.isEmpty || needsRescan {
            await startScan()
        }
    }

    // MARK: - Scanning

    func startScan() async {
        await MainActor.run {
            self.scanProgress.isScanning = true
            self.scanProgress.progressPercentage = 0
            self.scanProgress.projectsFound = 0
            self.scanProgress.directoriesScanned = 0
        }
        
        // Set excluded paths before scanning
        let languageManager = LanguageManager()
        let excludedPaths = languageManager.excludedPaths
        await scanner.setExcludedPaths(excludedPaths)

        let found = await scanner.scanAllDrives { progress in
            Task { @MainActor [weak self] in
                self?.scanProgress = progress
            }
        }

        let unique = deduplicatedByPath(found)

        await MainActor.run {
            self.projects = unique
            self.applyFilters()
            self.scanProgress.isScanning = false
        }

        await index.saveProjects(unique)
    }

    // MARK: - Deduplication

    private func deduplicatedByPath(_ list: [ProjectInfo]) -> [ProjectInfo] {
        var seen = Set<String>()
        return list.filter {
            let resolved = URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path
            return seen.insert(resolved).inserted
        }
    }

    // MARK: - Filtering

    func applyFilters() {
        var result = projects

        if selectedCategory != "All" {
            result = result.filter { $0.category.rawValue == selectedCategory }
        }

        if let selectedTag {
            result = result.filter { $0.tags.contains(selectedTag) }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { project in
                project.name.lowercased().contains(query) ||
                project.path.lowercased().contains(query) ||
                project.projectType.lowercased().contains(query) ||
                project.tags.contains { $0.lowercased().contains(query) }
            }
        }

        filteredProjects = result
        calculateFilteredStats()
    }

    // MARK: - Stats Calculation
    
    private func calculateFilteredStats() {
        statsTask?.cancel()
        
        let currentProjects = filteredProjects
        if currentProjects.isEmpty {
            filteredTotalFiles = 0
            filteredTotalLines = 0
            isCalculatingStats = false
            return
        }
        
        statsTask = Task {
            await MainActor.run { isCalculatingStats = true }
            
            var files = 0
            var lines = 0
            var needsSave = false
            
            for project in currentProjects {
                if Task.isCancelled { return }
                
                if let f = project.totalFiles, let l = project.totalLines, refreshedCountIDs.contains(project.id) {
                    files += f
                    lines += l
                } else {
                    let result = await CodeAnalyzer.analyze(for: project)
                    files += result.totalFiles
                    lines += result.totalLines
                    
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.refreshedCountIDs.insert(project.id)
                            // Unchanged counts must not republish the project list.
                            guard project.totalFiles != result.totalFiles || project.totalLines != result.totalLines else { return }
                            if let idx = self.projects.firstIndex(where: { $0.id == project.id }) {
                                self.projects[idx].totalFiles = result.totalFiles
                                self.projects[idx].totalLines = result.totalLines
                                needsSave = true
                            }
                            if let fIdx = self.filteredProjects.firstIndex(where: { $0.id == project.id }) {
                                self.filteredProjects[fIdx].totalFiles = result.totalFiles
                                self.filteredProjects[fIdx].totalLines = result.totalLines
                            }
                        }
                    }
                }
            }
            
            if !Task.isCancelled {
                await MainActor.run {
                    self.filteredTotalFiles = files
                    self.filteredTotalLines = lines
                    self.isCalculatingStats = false
                    if needsSave {
                        Task { await self.index.saveProjects(self.projects) }
                    }
                }
            }
        }
    }

    // MARK: - Grouping
    
    var groupedFilteredProjects: [(ProjectTimelineGroup, [ProjectInfo])] {
        let grouped = Dictionary(grouping: filteredProjects) { project in
            ProjectTimelineGroup.group(for: project.lastModified)
        }
        
        return grouped
            .map { ($0.key, $0.value.sorted(by: { $0.lastModified > $1.lastModified })) }
            .sorted(by: { $0.0.rawValue < $1.0.rawValue })
    }

    // MARK: - Navigation

    func selectProject(_ project: ProjectInfo) {
        selectedProject = project
        isShowingDetail = true
        isShowingProjectAnalysis = false
    }

    func goBack() {
        isShowingDetail = false
        isShowingProjectAnalysis = false
        selectedProject = nil
    }

    // MARK: - Quick Actions

    func openInVSCode(_ project: ProjectInfo) {
        runner.openInVSCode(at: project.path)
    }

    func openInXcode(_ project: ProjectInfo) {
        runner.openInXcode(at: project.path)
    }

    func installedEditors() -> [CodeEditor] {
        runner.installedEditors()
    }

    func openInEditor(_ editor: CodeEditor, project: ProjectInfo) {
        runner.openInEditor(editor, at: project.path)
    }

    func runProject(_ project: ProjectInfo, script: String? = nil) {
        runner.runProject(at: project.path, command: script)
    }
    
    func getProjectScripts(_ project: ProjectInfo) -> [ProjectRunner.PackageScript] {
        runner.getAllScripts(at: project.path)
    }
    
    func hasNodeModules(_ project: ProjectInfo) -> Bool {
        runner.hasNodeModules(at: project.path)
    }

    func openTerminal(_ project: ProjectInfo) {
        runner.openTerminal(at: project.path)
    }

    func revealInFinder(_ project: ProjectInfo) {
        runner.revealInFinder(at: project.path)
    }
}
