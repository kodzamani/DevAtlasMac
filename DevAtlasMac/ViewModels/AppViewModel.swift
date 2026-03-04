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
    var isGridView: Bool = true
    var scanProgress = ScanProgress()
    var selectedProject: ProjectInfo?
    var isShowingDetail: Bool = false
    var isDarkMode: Bool = UserDefaults.standard.bool(forKey: "isDarkMode") {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    var selectedTab: AppTab = .atlas
    var notebookSearchScope: NotebookSearchScope = .allNotes
    
    // Navigation to notebook
    var pendingNavigateToNoteId: String?

    // MARK: - Stats
    private var statsTask: Task<Void, Never>?
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
        
        for i in cached.indices {
            cached[i].totalFiles = nil
            cached[i].totalLines = nil
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
                
                if let f = project.totalFiles, let l = project.totalLines {
                    files += f
                    lines += l
                } else {
                    let result = await CodeAnalyzer.analyze(for: project)
                    files += result.totalFiles
                    lines += result.totalLines
                    
                    if !Task.isCancelled {
                        await MainActor.run {
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
    }

    func goBack() {
        isShowingDetail = false
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
