// swiftc -parse-as-library DevAtlasMac/Models/CodingAgent.swift DevAtlasMac/Services/AgentDetector.swift \
// Tests/AgentDetectorTests.swift -o /tmp/devatlas-agent-tests && /tmp/devatlas-agent-tests
import Foundation

@main
struct AgentDetectorTests {
    struct Failure: Error { let message: String }
    static func expect(_ value: Bool, _ message: String) throws {
        if !value { throw Failure(message: message) }
    }

    static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("devatlas-agents-\(UUID().uuidString)")
        let pathDir = root.appendingPathComponent("bin")
        let homeDir = root.appendingPathComponent("home")
        let opencodeDir = homeDir.appendingPathComponent(".opencode/bin")
        try fm.createDirectory(at: pathDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: opencodeDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        func makeExecutable(_ url: URL, mode: Int = 0o755) throws {
            try "#!/bin/sh\necho 'fake 1.2.3'\n".write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
        }
        try makeExecutable(pathDir.appendingPathComponent("claude"))
        try makeExecutable(opencodeDir.appendingPathComponent("opencode"))
        try makeExecutable(pathDir.appendingPathComponent("antigravity"))
        // Not executable: must be ignored.
        try makeExecutable(pathDir.appendingPathComponent("gemini"), mode: 0o644)
        // A directory with the agent's name must not count either.
        try fm.createDirectory(at: pathDir.appendingPathComponent("qwen"), withIntermediateDirectories: true)

        func agent(_ id: String) -> CodingAgent { CodingAgent.allKnown.first { $0.id == id }! }
        func resolve(_ id: String) -> String? {
            // Only the temp folders, so the machine's real installs do not leak into the test.
            let a = agent(id)
            let homeOnly = CodingAgent(id: a.id, name: a.name, executables: a.executables,
                                       extraSearchPaths: a.extraSearchPaths.filter { $0.hasPrefix("~") }, promptStyle: a.promptStyle)
            return AgentDetector.resolve(homeOnly, pathDirectories: [pathDir.path], home: homeDir.path, includeShared: false)
        }

        try expect(resolve("claude") == pathDir.appendingPathComponent("claude").path, "claude on PATH")
        try expect(resolve("opencode") == opencodeDir.appendingPathComponent("opencode").path, "opencode from ~/.opencode/bin")
        try expect(resolve("antigravity") == pathDir.appendingPathComponent("antigravity").path, "antigravity falls back to second name")
        try expect(resolve("gemini") == nil, "non-executable file is skipped")
        try expect(resolve("qwen") == nil, "directory is skipped")
        try expect(resolve("amp") == nil, "missing agent is nil")

        try expect(agent("claude").launchArguments(prompt: "fix it") == ["fix it"], "claude positional")
        try expect(agent("opencode").launchArguments(prompt: " fix ") == ["--prompt", "fix"], "opencode flag, trimmed")
        try expect(agent("qwen").launchArguments(prompt: "x") == ["-i", "x"], "qwen interactive flag")
        try expect(agent("claude").launchArguments(prompt: "   ") == [], "blank prompt adds nothing")
        try expect(agent("antigravity").launchArguments(prompt: "x") == [], "typed agent has no args")
        try expect(agent("antigravity").typedPrompt("x") == "x", "typed agent types the prompt")
        try expect(agent("claude").typedPrompt("x") == nil, "positional agent does not type")

        try expect(AgentDetector.parseVersion("2.1.4 (Claude Code)") == "2.1.4", "version from claude")
        try expect(AgentDetector.parseVersion("codex-cli 0.46.0") == "0.46.0", "version from codex")
        try expect(AgentDetector.parseVersion("no version") == nil, "no version")

        let env = AgentDetector.parseNullSeparated("PATH=/a:/b\0EMPTY=\0EQ=a=b\0=bad\0")
        try expect(env == ["PATH": "/a:/b", "EMPTY": "", "EQ": "a=b"], "null separated env")

        let login = AgentDetector.loginShellEnvironment()
        try expect(login["PATH"]?.isEmpty == false, "login shell env has PATH")
        let version = AgentDetector.version(of: pathDir.appendingPathComponent("claude").path, environment: login)
        try expect(version == "1.2.3", "version runs the binary")

        print("AgentDetectorTests passed")
    }
}

