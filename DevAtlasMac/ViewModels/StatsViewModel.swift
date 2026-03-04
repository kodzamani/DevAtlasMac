import SwiftUI
import Observation

@Observable
final class StatsViewModel {
    var dateRange: DateRangeFilter = .month {
        didSet {
            // Recalculate or filter stats when date range changes
            Task { await loadGitStats(for: currentProjects) }
        }
    }
    
    var gitDailyStats: [GitDailyStat] = []
    var projectMetrics: [ProjectMetric] = []
    var projectFileMetrics: [ProjectMetric] = []
    var projectTypeMetrics: [ProjectMetric] = []
    var isCalculating: Bool = false
    
    // Internal state
    private var currentProjects: [ProjectInfo] = []
    private var statsTask: Task<Void, Never>?
    
    // Performance optimization: Cache metrics
    private var cachedProjectMetrics: [ProjectMetric]?
    private var cachedFileMetrics: [ProjectMetric]?
    private var cachedTypeMetrics: [ProjectMetric]?
    private var lastProjectsHash: Int = 0
    
    func refreshStats(with projects: [ProjectInfo]) async {
        self.currentProjects = projects
        await calculateProjectMetrics()
        await loadGitStats(for: projects)
    }
    
    func getProject(named name: String) -> ProjectInfo? {
        currentProjects.first(where: { $0.name == name })
    }
    
    func getActivityLevel(for projectName: String) -> ActivityLevel {
        // Calculate based on recent git activity (last 30 days)
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let recentStats = gitDailyStats.filter { stat in
            stat.projectName == projectName &&
            stat.date >= thirtyDaysAgo
        }
        
        let totalChanges = recentStats.reduce(0) { $0 + $1.totalChanges }
        
        if totalChanges > 100 {
            return .high
        } else if totalChanges > 20 {
            return .medium
        } else {
            return .low
        }
    }
    
    func getLastCommitDate(for projectName: String) -> Date? {
        return gitDailyStats
            .filter { $0.projectName == projectName }
            .sorted { $0.date > $1.date }
            .first?.date
    }
    
    private func loadGitStats(for projects: [ProjectInfo]) async {
        statsTask?.cancel()
        
        let range = self.dateRange
        statsTask = Task {
            await MainActor.run { isCalculating = true }
            
            let stats = await GitStatsService.shared.fetchGitStats(for: projects, in: range)
            
            if !Task.isCancelled {
                await MainActor.run {
                    self.gitDailyStats = stats
                    self.isCalculating = false
                }
            }
        }
    }
    
    private func calculateProjectMetrics() async {
        let projectsHash = currentProjects.hashValue
        
        // Check if we can use cached data
        if cachedProjectMetrics != nil &&
           cachedFileMetrics != nil &&
           cachedTypeMetrics != nil &&
           lastProjectsHash == projectsHash {
            await MainActor.run {
                self.projectMetrics = cachedProjectMetrics!
                self.projectFileMetrics = cachedFileMetrics!
                self.projectTypeMetrics = cachedTypeMetrics!
            }
            return
        }
        
        // Calculate metrics in background for better performance
        let (sortedLines, sortedFiles, sortedTypes) = await Task.detached(priority: .userInitiated) {
            var metrics: [ProjectMetric] = []
            var fileMetrics: [ProjectMetric] = []
            var typeCounts: [String: Int] = [:]
            
            for project in self.currentProjects {
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
            let sortedLines = metrics.sorted(by: { $0.value > $1.value })
            let sortedFiles = fileMetrics.sorted(by: { $0.value > $1.value })
            let sortedTypes = typeCounts.map { ProjectMetric(projectName: $0.key, projectType: $0.key, value: $0.value) }.sorted(by: { $0.value > $1.value })
            
            return (sortedLines, sortedFiles, sortedTypes)
        }.value
        
        // Cache the results
        cachedProjectMetrics = sortedLines
        cachedFileMetrics = sortedFiles
        cachedTypeMetrics = sortedTypes
        lastProjectsHash = projectsHash
        
        await MainActor.run {
            self.projectMetrics = sortedLines
            self.projectFileMetrics = sortedFiles
            self.projectTypeMetrics = sortedTypes
        }
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
