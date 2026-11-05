// Run from the repository root:
// swiftc -parse-as-library DevAtlasMac/Services/ProjectOverviewService.swift \
//   Tests/ProjectOverviewServiceTests.swift -o /tmp/devatlas-overview-tests && /tmp/devatlas-overview-tests
import Foundation

@main
struct ProjectOverviewServiceTests {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevAtlas overview tests \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try checkRemoteURLs()
        try expect(ProjectOverviewService.changedFileCount(in: "R  new\0old\0 M file\nname\0?? untracked\0") == 3,
                   "Renames and filenames containing newlines must count once")
        try expect(ProjectOverviewService.changedFileCount(in: "C  copy\0source\0") == 1, "Copies count once")
        try expect(ProjectOverviewService.changedFileCount(in: "") == 0, "Clean status")

        if case .notRepository = await ProjectOverviewService.gitSummary(at: root.path) {} else {
            throw Failure("Plain directories are not repositories")
        }
        try await checkReadmes(in: root)
        try await checkGit(in: root)
        print("ProjectOverviewService: all checks passed (README, remotes, status, commits, detached HEAD, worktrees).")
    }

    private static func checkRemoteURLs() throws {
        let examples = [
            "git@github.com:owner/repo.git": "https://github.com/owner/repo",
            "ssh://git@gitlab.com:2222/group/repo.git": "https://gitlab.com/group/repo",
            "git://example.com/owner/repo.git": "https://example.com/owner/repo",
            "https://user:secret@example.com/owner/repo.git?token=secret#fragment": "https://example.com/owner/repo",
            "https://dev.azure.com/org/project/_git/repo": "https://dev.azure.com/org/project/_git/repo"
        ]
        for (input, expected) in examples {
            try expect(ProjectOverviewService.repositoryWebURL(input)?.absoluteString == expected, "Remote: \(input)")
        }
        for input in ["/tmp/repo", "file:///tmp/repo", "javascript:alert(1)", "", "../repo.git"] {
            try expect(ProjectOverviewService.repositoryWebURL(input) == nil, "Non-web remote must not open: \(input)")
        }
    }

    private static func checkReadmes(in root: URL) async throws {
        if case .missing = await ProjectOverviewService.readme(at: root.path) {} else {
            throw Failure("Missing README")
        }
        let directory = root.appendingPathComponent("README", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if case .missing = await ProjectOverviewService.readme(at: root.path) {} else {
            throw Failure("A directory named README must be ignored")
        }
        try Data("Plain text".utf8).write(to: root.appendingPathComponent("README.txt"))
        if case .document(let document) = await ProjectOverviewService.readme(at: root.path) {
            try expect(!document.isMarkdown && document.content == "Plain text", "Plain README")
        } else { throw Failure("Plain README loading") }

        let markdown = root.appendingPathComponent("ReadMe.MD")
        let content = "# Başlık\nTürkçe içerik 🎉\n" + String(repeating: "a", count: 8_000)
        try Data(content.utf8).write(to: markdown)
        if case .document(let document) = await ProjectOverviewService.readme(at: root.path) {
            try expect(document.isMarkdown && document.content == content, "Case-insensitive Markdown preferred over TXT")
            try expect(document.preview.count == 6_000, "Inline preview bounded without truncating full content")
        } else { throw Failure("Markdown loading") }

        try Data().write(to: markdown)
        if case .document(let document) = await ProjectOverviewService.readme(at: root.path) {
            try expect(document.content.isEmpty, "Empty README is a valid document")
        } else { throw Failure("Empty README loading") }

        try "UTF-16 Türkçe".data(using: .utf16)!.write(to: markdown)
        if case .document(let document) = await ProjectOverviewService.readme(at: root.path) {
            try expect(document.content == "UTF-16 Türkçe", "UTF-16 README")
        } else { throw Failure("UTF-16 loading") }

        try Data(repeating: 97, count: 512 * 1_024 + 1).write(to: markdown)
        if case .tooLarge(let url) = await ProjectOverviewService.readme(at: root.path) {
            try expect(url.resolvingSymlinksInPath() == markdown.resolvingSymlinksInPath(),
                       "Oversized README can be opened externally")
        } else { throw Failure("README read size limit") }

        if case .unreadable = await ProjectOverviewService.readme(at: root.appendingPathComponent("missing").path) {} else {
            throw Failure("Inaccessible project folder")
        }
        try FileManager.default.removeItem(at: markdown)
        try FileManager.default.removeItem(at: root.appendingPathComponent("README.txt"))
        try FileManager.default.removeItem(at: directory)
    }

    private static func checkGit(in root: URL) async throws {
        try git(["init", "-q", "-b", "main"], at: root)
        try git(["config", "user.name", "Overview Tests"], at: root)
        try git(["config", "user.email", "overview@example.invalid"], at: root)
        try git(["config", "commit.gpgsign", "false"], at: root)
        var summary = try await summary(at: root)
        try expect(summary.branch == "main" && summary.commit == nil && summary.changedFiles == 0, "Unborn branch")

        let file = root.appendingPathComponent("hello\nworld.txt")
        try Data("Hello".utf8).write(to: file)
        summary = try await self.summary(at: root)
        try expect(summary.changedFiles == 1, "Untracked file with newline")
        try git(["add", "."], at: root)
        try git(["commit", "-q", "-m", "İlk commit 🎉"], at: root)
        try git(["remote", "add", "origin", "git@github.com:owner/example.git"], at: root)
        summary = try await self.summary(at: root)
        try expect(summary.commit?.subject == "İlk commit 🎉" && summary.changedFiles == 0, "Commit summary")
        try expect(summary.remoteURL?.absoluteString == "https://github.com/owner/example", "Remote integration")
        try expect(summary.commit!.date.timeIntervalSinceNow > -120, "Commit timestamp")

        try git(["mv", "hello\nworld.txt", "renamed file.txt"], at: root)
        try Data("New".utf8).write(to: root.appendingPathComponent("untracked.txt"))
        summary = try await self.summary(at: root)
        try expect(summary.changedFiles == 2, "Staged rename and untracked file")
        try git(["commit", "-q", "-m", "Rename"], at: root)
        try git(["checkout", "--detach", "-q"], at: root)
        summary = try await self.summary(at: root)
        try expect(summary.branch == nil && summary.commit != nil, "Detached HEAD")

        let worktree = root.appendingPathComponent("linked worktree", isDirectory: true)
        try git(["worktree", "add", "-q", "-b", "worktree-test", worktree.path], at: root)
        summary = try await self.summary(at: worktree)
        try expect(summary.branch == "worktree-test" && summary.changedFiles == 0, "Linked worktree with .git file")
    }

    private static func summary(at url: URL) async throws -> ProjectGitSummary {
        guard case .repository(let summary) = await ProjectOverviewService.gitSummary(at: url.path) else {
            throw Failure("Expected repository at \(url.path)")
        }
        return summary
    }

    private static func git(_ arguments: [String], at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", url.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try expect(process.terminationStatus == 0, "Fixture git command failed: \(arguments)")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(message) }
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
