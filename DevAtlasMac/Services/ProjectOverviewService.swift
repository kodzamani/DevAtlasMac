import Foundation

struct ProjectGitSummary: Sendable {
    let branch: String?
    let changedFiles: Int
    let commit: Commit?
    let remoteURL: URL?

    struct Commit: Sendable {
        let hash: String
        let subject: String
        let date: Date
    }
}

enum ProjectGitState: Sendable {
    case repository(ProjectGitSummary)
    case notRepository
    case unavailable
}

struct ProjectReadme: Sendable {
    let url: URL
    let content: String

    var isMarkdown: Bool {
        ["md", "markdown", "mdown"].contains(url.pathExtension.lowercased())
    }

    // Keep the inline preview inexpensive even for long documents.
    var preview: String { String(content.prefix(6_000)) }
}

enum ProjectReadmeState: Sendable {
    case document(ProjectReadme)
    case missing
    case unreadable
    case tooLarge(URL)
}

enum ProjectOverviewService {
    static func gitSummary(at path: String) async -> ProjectGitState {
        await inBackground { loadGitSummary(at: path) }
    }

    static func readme(at path: String) async -> ProjectReadmeState {
        await inBackground { loadReadme(at: path) }
    }

    private static func loadGitSummary(at path: String) -> ProjectGitState {
        guard let inside = git(["rev-parse", "--is-inside-work-tree"], at: path) else {
            return FileManager.default.isReadableFile(atPath: path) ? .notRepository : .unavailable
        }
        guard inside.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            return .notRepository
        }
        guard let status = git(["status", "--porcelain=v1", "-z", "--untracked-files=normal"], at: path) else {
            return .unavailable
        }

        let branch = git(["symbolic-ref", "--quiet", "--short", "HEAD"], at: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var commit: ProjectGitSummary.Commit?
        if let log = git(["log", "-1", "--format=%h%x00%s%x00%ct"], at: path) {
            let fields = log.trimmingCharacters(in: .newlines).components(separatedBy: "\0")
            if fields.count == 3, let timestamp = TimeInterval(fields[2]) {
                commit = .init(hash: fields[0], subject: fields[1], date: Date(timeIntervalSince1970: timestamp))
            }
        }
        let remote = git(["config", "--get", "remote.origin.url"], at: path)
            .flatMap(repositoryWebURL)
        return .repository(.init(
            branch: branch?.isEmpty == false ? branch : nil,
            changedFiles: changedFileCount(in: status),
            commit: commit,
            remoteURL: remote
        ))
    }

    /// In -z output a renamed/copied entry has a second, NUL-separated path.
    static func changedFileCount(in status: String) -> Int {
        let entries = status.split(separator: "\0", omittingEmptySubsequences: true)
        var index = 0
        var count = 0
        while index < entries.count {
            let entry = entries[index]
            guard entry.count >= 3 else { index += 1; continue }
            count += 1
            let flags = entry.prefix(2)
            index += flags.contains("R") || flags.contains("C") ? 2 : 1
        }
        return count
    }

    /// Convert common Git HTTPS, SSH and SCP remotes to browser URLs.
    static func repositoryWebURL(_ remote: String) -> URL? {
        let value = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        var components: URLComponents?
        if value.contains("://") {
            components = URLComponents(string: value)
            guard let scheme = components?.scheme?.lowercased(),
                  ["http", "https", "ssh", "git"].contains(scheme) else { return nil }
            if scheme == "ssh" || scheme == "git" {
                components?.scheme = "https"
                components?.port = nil
            }
        } else if let at = value.firstIndex(of: "@"),
                  let colon = value[at...].firstIndex(of: ":") {
            let host = value[value.index(after: at)..<colon]
            let path = value[value.index(after: colon)...]
            components = URLComponents(string: "https://\(host)/\(path)")
        }
        guard var result = components, let host = result.host, !host.isEmpty else { return nil }
        result.user = nil
        result.password = nil
        result.query = nil
        result.fragment = nil
        if result.path.hasSuffix(".git") { result.path.removeLast(4) }
        return result.url
    }

    private static func loadReadme(at path: String) -> ProjectReadmeState {
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        let names = ["readme.md", "readme.markdown", "readme.mdown", "readme.txt", "readme"]
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey]
            )
            let candidates = files.filter { names.contains($0.lastPathComponent.lowercased()) }
                .sorted {
                    let left = names.firstIndex(of: $0.lastPathComponent.lowercased())!
                    let right = names.firstIndex(of: $1.lastPathComponent.lowercased())!
                    return left == right ? $0.lastPathComponent < $1.lastPathComponent : left < right
                }
            guard let url = candidates.first(where: {
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }) else { return .missing }

            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let limit = 512 * 1_024
            let data = try handle.read(upToCount: limit + 1) ?? Data()
            guard data.count <= limit else { return .tooLarge(url) }
            guard let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16) else { return .unreadable }
            return .document(.init(url: url, content: content))
        } catch {
            return .unreadable
        }
    }

    /// No shell, network fetch or index refresh is needed to inspect a repository.
    private static func git(_ arguments: [String], at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["--no-optional-locks", "-C", path] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        defer { try? output.fileHandleForReading.close() }
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
        } catch {
            return nil
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
