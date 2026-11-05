import Foundation

actor GitStatsService {
    static let shared = GitStatsService()

    private struct DayStats: Sendable {
        var additions = 0
        var deletions = 0
        var commits = 0
    }

    /// A repository's log can only change when its HEAD does, so HEAD is part of the key.
    private struct CacheKey: Hashable {
        let path: String
        let head: String
        let author: String
        let since: String?
    }

    private static let maxConcurrentRepositories = 6
    private static let maxCacheEntries = 2000

    private var cache: [CacheKey: [String: DayStats]] = [:]
    private var author: String?

    private init() {}

    func fetchGitStats(for projects: [ProjectInfo], in range: DateRangeFilter) async -> [GitDailyStat] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let since = range.days
            .flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
            .map { dateFormatter.string(from: $0) }

        let author = await configuredAuthor()

        let repositories = projects.filter {
            let gitPath = URL(fileURLWithPath: $0.path).appendingPathComponent(".git").path
            return FileManager.default.fileExists(atPath: gitPath)
        }

        var allStats: [String: [String: DayStats]] = [:]

        await withTaskGroup(of: (name: String, stats: [String: DayStats]).self) { group in
            var remaining = repositories.makeIterator()

            func addTask(for project: ProjectInfo) {
                group.addTask {
                    (project.name, await self.projectStats(at: project.path, author: author, since: since))
                }
            }

            for _ in 0..<Self.maxConcurrentRepositories {
                guard let project = remaining.next() else { break }
                addTask(for: project)
            }

            for await (name, stats) in group {
                for (dateString, day) in stats {
                    var merged = allStats[dateString]?[name] ?? DayStats()
                    merged.additions += day.additions
                    merged.deletions += day.deletions
                    merged.commits += day.commits
                    allStats[dateString, default: [:]][name] = merged
                }

                if !Task.isCancelled, let project = remaining.next() {
                    addTask(for: project)
                }
            }
        }

        var result: [GitDailyStat] = []
        for (dateString, projectMap) in allStats {
            guard let date = dateFormatter.date(from: dateString) else { continue }
            for (projectName, day) in projectMap {
                result.append(GitDailyStat(date: date, projectName: projectName, additions: day.additions, deletions: day.deletions, commits: day.commits))
            }
        }

        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Per Repository

    private func projectStats(at path: String, author: String, since: String?) async -> [String: DayStats] {
        guard !Task.isCancelled,
              let head = await Self.git(["rev-parse", "HEAD"], at: path)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return [:]
        }

        let key = CacheKey(path: path, head: head, author: author, since: since)
        if let cached = cache[key] {
            return cached
        }

        var arguments = ["log", "--numstat", "--date=short", "--format=%ad"]
        if !author.isEmpty {
            arguments.append("--author=\(author)")
        }
        if let since {
            arguments.append("--since=\(since)")
        }

        guard !Task.isCancelled, let output = await Self.git(arguments, at: path) else {
            return [:]
        }

        let stats = await Self.inBackground { Self.parseLog(output) }

        if cache.count >= Self.maxCacheEntries {
            cache.removeAll()
        }
        cache[key] = stats
        return stats
    }

    private func configuredAuthor() async -> String {
        if let author { return author }
        let name = await Self.git(["config", "--global", "user.name"], at: nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        author = name
        return name
    }

    // MARK: - Parsing

    /// `--format=%ad` prints a date line per commit, followed by tab-separated numstat lines.
    private static func parseLog(_ output: String) -> [String: DayStats] {
        var stats: [String: DayStats] = [:]
        var currentDate = ""

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)

            if parts.count == 1 {
                currentDate = String(line)
                stats[currentDate, default: DayStats()].commits += 1
            } else if parts.count >= 2, !currentDate.isEmpty,
                      let added = Int(parts[0]), let deleted = Int(parts[1]) {
                // Binary files report "-" and don't parse as numbers.
                stats[currentDate, default: DayStats()].additions += added
                stats[currentDate, default: DayStats()].deletions += deleted
            }
        }

        return stats
    }

    // MARK: - Process

    /// Runs git off the actor and the cooperative pool. Returns nil if git fails.
    private static func git(_ arguments: [String], at path: String?) async -> String? {
        await inBackground {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            if let path {
                process.currentDirectoryURL = URL(fileURLWithPath: path)
            }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            defer { pipe.fileHandleForReading.closeFile() }

            do {
                try process.run()
            } catch {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: data, as: UTF8.self)
        }
    }

    private static func inBackground<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: work())
            }
        }
    }
}
