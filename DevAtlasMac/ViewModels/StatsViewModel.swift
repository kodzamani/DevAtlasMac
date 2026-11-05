import SwiftUI
import Observation

@MainActor
@Observable
final class StatsViewModel {
    var dateRange: DateRangeFilter = .month {
        didSet {
            guard dateRange != oldValue else { return }
            loadGitStats(force: true)
        }
    }
    
    var gitDailyStats: [GitDailyStat] = [] {
        didSet { rebuildGitLookups() }
    }
    var projectMetrics: [ProjectMetric] = [] {
        didSet { rebuildProjectNames() }
    }
    var projectFileMetrics: [ProjectMetric] = []
    var projectTypeMetrics: [ProjectMetric] = []
    /// False only until the first metrics are in.
    private(set) var hasLoadedMetrics = false
    /// True while the git section has nothing valid to show. A refresh of the range already
    /// on screen keeps the current data visible instead.
    private(set) var isLoadingGitStats = false
    /// Sorted names across metrics and git activity, which keeps project colors stable.
    private(set) var allProjectNames: [String] = []
    
    // Internal state
    private struct GitRequest: Equatable {
        let range: DateRangeFilter
        let paths: Set<String>
    }
    
    private var currentProjects: [ProjectInfo] = []
    private var statsTask: Task<Void, Never>?
    private var runningRequest: GitRequest?
    private var loadedRequest: GitRequest?
    private var lastCommitByProject: [String: Date] = [:]
    private var recentChangesByProject: [String: Int] = [:]
    
    /// Reloads everything. Unchanged repositories come from the git stats cache.
    func refreshStats(with projects: [ProjectInfo]) {
        currentProjects = projects
        calculateProjectMetrics()
        loadGitStats(force: true)
    }
    
    /// Updates for a changed project list. Line count updates don't touch git; only a
    /// different set of projects does.
    func projectsDidChange(_ projects: [ProjectInfo]) {
        currentProjects = projects
        calculateProjectMetrics()
        loadGitStats(force: false)
    }
    
    func getProject(named name: String) -> ProjectInfo? {
        currentProjects.first(where: { $0.name == name })
    }
    
    func getActivityLevel(for projectName: String) -> ActivityLevel {
        let totalChanges = recentChangesByProject[projectName] ?? 0
        
        if totalChanges > 100 {
            return .high
        } else if totalChanges > 20 {
            return .medium
        } else {
            return .low
        }
    }
    
    func getLastCommitDate(for projectName: String) -> Date? {
        lastCommitByProject[projectName]
    }
    
    private func loadGitStats(force: Bool) {
        let projects = currentProjects
        let request = GitRequest(range: dateRange, paths: Set(projects.map(\.path)))
        
        guard request != runningRequest else { return }
        guard force || request != loadedRequest else { return }
        
        statsTask?.cancel()
        runningRequest = request
        isLoadingGitStats = loadedRequest?.range != request.range
        
        statsTask = Task {
            let stats = await GitStatsService.shared.fetchGitStats(for: projects, in: request.range)
            guard !Task.isCancelled else { return }
            
            gitDailyStats = stats
            loadedRequest = request
            runningRequest = nil
            isLoadingGitStats = false
        }
    }
    
    private func calculateProjectMetrics() {
        var metrics: [ProjectMetric] = []
        var fileMetrics: [ProjectMetric] = []
        var typeCounts: [String: Int] = [:]
        
        for project in currentProjects {
            let loc = project.totalLines ?? 0
            if loc > 0 {
                metrics.append(ProjectMetric(projectName: project.name, projectType: project.projectType, value: loc))
            }
            
            let files = project.totalFiles ?? 0
            if files > 0 {
                fileMetrics.append(ProjectMetric(projectName: project.name, projectType: project.projectType, value: files))
            }
            
            typeCounts[project.projectType, default: 0] += 1
        }
        
        // Sort by value descending
        projectMetrics = metrics.sorted(by: { $0.value > $1.value })
        projectFileMetrics = fileMetrics.sorted(by: { $0.value > $1.value })
        projectTypeMetrics = typeCounts
            .map { ProjectMetric(projectName: $0.key, projectType: $0.key, value: $0.value) }
            .sorted(by: { $0.value > $1.value })
        hasLoadedMetrics = true
    }
    
    private func rebuildGitLookups() {
        // Activity levels look at the last 30 days of what's loaded.
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var lastCommit: [String: Date] = [:]
        var recentChanges: [String: Int] = [:]
        
        for stat in gitDailyStats {
            if stat.date > (lastCommit[stat.projectName] ?? .distantPast) {
                lastCommit[stat.projectName] = stat.date
            }
            if stat.date >= thirtyDaysAgo {
                recentChanges[stat.projectName, default: 0] += stat.totalChanges
            }
        }
        
        lastCommitByProject = lastCommit
        recentChangesByProject = recentChanges
        rebuildProjectNames()
    }
    
    private func rebuildProjectNames() {
        allProjectNames = Array(Set(projectMetrics.map(\.projectName) + gitDailyStats.map(\.projectName))).sorted()
    }
    
    // MARK: - Export Functions
    func exportAsCSV() {
        let csvContent = StatsExportService.shared.exportToCSV(
            projectMetrics: projectMetrics,
            fileMetrics: projectFileMetrics,
            typeMetrics: projectTypeMetrics
        )
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "DevAtlas_Stats_\(dateFormatter.string(from: Date())).csv"
        
        if let url = StatsExportService.shared.saveExportToFile(content: csvContent, fileName: fileName) {
            print("Export saved to: \(url.path)")
        }
    }
}
