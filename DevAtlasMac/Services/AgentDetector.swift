import Foundation

/// Finds installed coding-agent CLIs. A GUI app starts with launchd's short PATH, so the user's
/// login shell is asked for its environment once and that is used both to search and to launch.
enum AgentDetector {
    private static let cache = EnvironmentCache()

    /// The user's login-shell environment, falling back to this process's environment.
    static func loginShellEnvironment() -> [String: String] {
        if let cached = cache.value { return cached }
        let base = ProcessInfo.processInfo.environment
        let shell = base["SHELL"].flatMap { FileManager.default.isExecutableFile(atPath: $0) ? $0 : nil } ?? "/bin/zsh"
        let marker = "__DEVATLAS_ENV__"
        // Interactive too, since many users extend PATH in .zshrc rather than .zprofile.
        var parsed: [String: String]?
        for flags in [["-l", "-i"], ["-l"]] {
            guard let output = run(executable: shell, arguments: flags + ["-c", "printf '\(marker)'; /usr/bin/env -0"],
                                   environment: base, timeout: 6),
                  let range = output.range(of: marker, options: .backwards) else { continue }
            let env = parseNullSeparated(String(output[range.upperBound...]))
            if env["PATH"] != nil { parsed = env; break }
        }
        var result = base
        if let parsed {
            // Keep the shell's values but drop ones that only make sense inside that shell.
            for (key, value) in parsed where !["_", "SHLVL", "PWD", "OLDPWD"].contains(key) { result[key] = value }
        }
        cache.value = result
        return result
    }

    static func parseNullSeparated(_ text: String) -> [String: String] {
        var env: [String: String] = [:]
        for entry in text.split(separator: "\0") {
            guard let eq = entry.firstIndex(of: "="), eq != entry.startIndex else { continue }
            env[String(entry[..<eq])] = String(entry[entry.index(after: eq)...])
        }
        return env
    }

    /// The first executable for the agent: login PATH first, then the agent's own install folders.
    static func resolve(_ agent: CodingAgent, pathDirectories: [String], home: String,
                        includeShared: Bool = true, fileManager: FileManager = .default) -> String? {
        let shared = includeShared ? CodingAgent.sharedSearchPaths : []
        let expanded = (pathDirectories + agent.extraSearchPaths + shared).map { dir in
            dir.hasPrefix("~") ? home + dir.dropFirst() : dir
        }
        var seen = Set<String>()
        let directories = expanded.filter { !$0.isEmpty && seen.insert($0).inserted }
        for name in agent.executables {
            for dir in directories {
                let candidate = (dir as NSString).appendingPathComponent(name)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: candidate, isDirectory: &isDirectory), !isDirectory.boolValue,
                   fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        return nil
    }

    static func detect() async -> [DetectedAgent] {
        let env = loginShellEnvironment()
        let dirs = (env["PATH"] ?? "").split(separator: ":").map(String.init)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let found = CodingAgent.allKnown.map { DetectedAgent(agent: $0, path: resolve($0, pathDirectories: dirs, home: home)) }
        return await withTaskGroup(of: (Int, String?).self) { group in
            for (index, item) in found.enumerated() {
                guard let path = item.path else { continue }
                group.addTask { (index, version(of: path, environment: env)) }
            }
            var result = found
            for await (index, version) in group { result[index].version = version }
            return result
        }
    }

    /// A short version string from `--version`, such as "2.1.4".
    static func version(of path: String, environment: [String: String]) -> String? {
        guard let output = run(executable: path, arguments: ["--version"], environment: environment, timeout: 4) else { return nil }
        return parseVersion(output)
    }

    static func parseVersion(_ output: String) -> String? {
        let pattern = #"\d+\.\d+(?:\.\d+)?(?:[-+][0-9A-Za-z.]+)?"#
        return output.range(of: pattern, options: .regularExpression).map { String(output[$0]) }
    }

    // MARK: - Process

    /// Runs a command with output going to a file, so a chatty child cannot fill a pipe and stall.
    private static func run(executable: String, arguments: [String], environment: [String: String],
                            timeout: TimeInterval) -> String? {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devatlas-agent-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: outputURL) else { return nil }
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: outputURL)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = handle
        process.standardError = handle
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        do { try process.run() } catch { return nil }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if done.wait(timeout: .now() + 1) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            return nil
        }
        return (try? Data(contentsOf: outputURL)).map { String(decoding: $0, as: UTF8.self) }
    }

    private final class EnvironmentCache: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [String: String]?
        var value: [String: String]? {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }
}
