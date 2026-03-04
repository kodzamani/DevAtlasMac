import Foundation

actor GitStatsService {
    static let shared = GitStatsService()

    private init() {}

    func fetchGitStats(for projects: [ProjectInfo], in range: DateRangeFilter) async -> [GitDailyStat] {
        var allStats: [String: [String: (additions: Int, deletions: Int, commits: Int)]] = [:]

        let calendar = Calendar.current
        let today = Date()
        let cutoffDate: Date?
        if let days = range.days {
            cutoffDate = calendar.date(byAdding: .day, value: -days, to: today)
        } else {
            cutoffDate = nil
        }

        let author = await getGitConfigUser()
        
        for project in projects {
            let gitPath = URL(fileURLWithPath: project.path).appendingPathComponent(".git").path
            if FileManager.default.fileExists(atPath: gitPath) {
                let projectStats = await fetchProjectStats(at: project.path, author: author, since: cutoffDate)
                for (dateStr, stats) in projectStats {
                    if allStats[dateStr] == nil {
                        allStats[dateStr] = [:]
                    }
                    let current = allStats[dateStr]?[project.name] ?? (0, 0, 0)
                    allStats[dateStr]?[project.name] = (current.additions + stats.additions, current.deletions + stats.deletions, current.commits + stats.commits)
                }
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var result: [GitDailyStat] = []
        for (dateStr, projectMap) in allStats {
            if let date = dateFormatter.date(from: dateStr) {
                for (projectName, stats) in projectMap {
                    result.append(GitDailyStat(date: date, projectName: projectName, additions: stats.additions, deletions: stats.deletions, commits: stats.commits))
                }
            }
        }
        
        return result.sorted { $0.date < $1.date }
    }

    private func getGitConfigUser() async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "--global", "user.name"]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        defer {
            pipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let name = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                return name
            }
        } catch {
            return ""
        }
        return ""
    }

    private func fetchProjectStats(at path: String, author: String, since: Date?) async -> [String: (additions: Int, deletions: Int, commits: Int)] {
        var args = ["log", "--numstat", "--date=short", "--format=%ad"]
        if !author.isEmpty {
            args.append("--author=\(author)")
        }
        if let sinceDate = since {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            args.append("--since=\(df.string(from: sinceDate))")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.arguments = args
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        var projectStats: [String: (additions: Int, deletions: Int, commits: Int)] = [:]
        
        defer {
            pipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                var currentDate = ""
                
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    
                    if trimmed.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil {
                        currentDate = trimmed
                        let current = projectStats[currentDate] ?? (0, 0, 0)
                        projectStats[currentDate] = (current.additions, current.deletions, current.commits + 1)
                    } else {
                        let parts = trimmed.components(separatedBy: "\t")
                        if parts.count >= 2 {
                            if parts[0] == "-" || parts[1] == "-" { continue }
                            let added = Int(parts[0]) ?? 0
                            let deleted = Int(parts[1]) ?? 0
                            
                            if !currentDate.isEmpty {
                                let current = projectStats[currentDate] ?? (0, 0, 0)
                                projectStats[currentDate] = (current.additions + added, current.deletions + deleted, current.commits)
                            }
                        }
                    }
                }
            }
        } catch {
            // Ignore errors silently for individual projects
        }
        
        return projectStats
    }
}
