import Foundation
import Darwin

/// All commands use argument arrays. Output goes to files so a full stderr pipe cannot deadlock Process.
enum DockerService {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    struct CommandResult: Sendable {
        let status: Int32
        let output: String
        let error: String
    }
    struct Snapshot: Sendable {
        var state: DockerDaemonState
        var containers: [DockerContainer] = []
        var runtimes: [DockerRuntime] = []
        var warning: String?
    }

    static func cliPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (["/opt/homebrew/bin/docker", "/usr/local/bin/docker", home + "/.orbstack/run/bin/docker", home + "/.rd/bin/docker", "/Applications/Docker.app/Contents/Resources/bin/docker"] +
                (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/docker" })
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func installedRuntimes() -> [DockerRuntime] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var result: [DockerRuntime] = []
        // CLI symlinks also reveal apps installed on external volumes or outside /Applications.
        let resolvedCLI = cliPath().map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
        let linkedApp: String? = resolvedCLI.flatMap { path in
            path.range(of: ".app/").map { String(path[..<$0.lowerBound]) + ".app" }
        }
        for name in ["Docker", "OrbStack", "Rancher Desktop"] {
            if let path = (["/Applications/\(name).app", home + "/Applications/\(name).app"] + [linkedApp].compactMap { $0 }.filter { URL(fileURLWithPath: $0).lastPathComponent == name + ".app" }).first(where: { FileManager.default.fileExists(atPath: $0) }) {
                result.append(.init(name: name == "Docker" ? "Docker Desktop" : name, launchPath: path, isCommand: false))
            }
        }
        if let path = ["/opt/homebrew/bin/colima", "/usr/local/bin/colima"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            result.append(.init(name: "Colima", launchPath: path, isCommand: true))
        }
        return result
    }

    static func snapshot() throws -> Snapshot {
        let runtimes = installedRuntimes()
        guard cliPath() != nil else { return Snapshot(state: runtimes.isEmpty ? .notInstalled : .stopped, runtimes: runtimes) }
        let info = try command(["info", "--format", "{{json .ServerVersion}}"], timeout: 10, requireSuccess: false)
        guard info.status == 0 else { return Snapshot(state: .stopped, runtimes: runtimes, warning: info.error) }
        let ps = try command(["ps", "-a", "--no-trunc", "--format", "json"])
        var containers = try parseContainers(ps.output)
        // Inspect adds structured labels, published ports and host bind paths; ps's Mounts only lists names.
        for batch in stride(from: 0, to: containers.count, by: 80) {
            let ids = containers[batch..<min(batch + 80, containers.count)].map(\.id)
            let details = try command(["inspect", "--type", "container"] + ids, requireSuccess: false)
            if details.status == 0 { try applyInspection(details.output, to: &containers) }
        }
        var warning: String?
        if containers.contains(where: \.isRunning) {
            do {
                let stats = try command(["stats", "--no-stream", "--no-trunc", "--format", "json"], timeout: 15)
                try applyStats(stats.output, to: &containers)
            } catch { warning = error.localizedDescription }
        }
        return Snapshot(state: .running, containers: containers.sorted { ($0.name, $0.id) < ($1.name, $1.id) }, runtimes: runtimes, warning: warning)
    }

    static func perform(_ action: DockerContainerAction, containerID: String) throws {
        guard containerID.range(of: "^[a-f0-9]{12,64}$", options: .regularExpression) != nil else { throw Failure(message: "docker.error.containerID".localized) }
        _ = try command(action.arguments + [containerID], timeout: 60)
    }
    static func logs(containerID: String) throws -> String {
        guard containerID.range(of: "^[a-f0-9]{12,64}$", options: .regularExpression) != nil else { throw Failure(message: "docker.error.containerID".localized) }
        let result = try command(["logs", "--tail", "300", "--timestamps", containerID])
        return result.output + (result.error.isEmpty ? "" : "\n" + result.error)
    }
    static func compose(_ action: DockerStackAction, fileURL: URL) throws {
        _ = try command(["compose", "--project-directory", fileURL.deletingLastPathComponent().path, "-f", fileURL.path] + action.arguments,
                        directory: fileURL.deletingLastPathComponent(), timeout: 600)
    }
    static func validate(_ source: String, fileURL: URL) throws {
        // stdin validates the draft without overwriting the user's file. The project directory keeps relative paths and .env correct.
        _ = try command(["compose", "--project-directory", fileURL.deletingLastPathComponent().path, "-f", "-", "config", "--quiet"],
                        directory: fileURL.deletingLastPathComponent(), input: source)
    }
    static func startRuntime(_ runtime: DockerRuntime) throws {
        if runtime.isCommand { _ = try run(executable: runtime.launchPath, arguments: ["start"], timeout: 180) }
        else { _ = try run(executable: "/usr/bin/open", arguments: ["-a", runtime.launchPath]) }
    }
    static func openShell(containerID: String) throws {
        guard let cli = cliPath(), containerID.range(of: "^[a-f0-9]{12,64}$", options: .regularExpression) != nil else { throw Failure(message: "docker.error.cli".localized) }
        let shellCommand = shellQuote(cli) + " exec -it " + shellQuote(containerID) + " /bin/sh"
        let script = "tell application \"Terminal\"\nactivate\ndo script \"" + shellCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"\nend tell"
        _ = try run(executable: "/usr/bin/osascript", arguments: ["-e", script])
    }
    static func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    static func discoverStacks(projects: [(id: String, name: String, path: String)]) -> [DockerComposeStack] {
        let names = ["compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml"]
        return projects.flatMap { project in
            names.compactMap { name in
                let url = URL(fileURLWithPath: project.path).appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                return DockerComposeStack(projectID: project.id, projectName: project.name, fileURL: url)
            }
        }
    }

    static func parseContainers(_ output: String) throws -> [DockerContainer] {
        try jsonRows(output).map { row in
            guard let id = row["ID"] as? String, let name = row["Names"] as? String else { throw Failure(message: "docker.error.output".localized) }
            return DockerContainer(id: id, name: name, image: row["Image"] as? String ?? "", status: row["Status"] as? String ?? "", state: row["State"] as? String ?? "unknown")
        }
    }
    static func applyInspection(_ output: String, to containers: inout [DockerContainer]) throws {
        for row in try jsonRows(output) {
            guard let id = row["Id"] as? String, let index = containers.firstIndex(where: { $0.id == id }) else { continue }
            let labels = (row["Config"] as? [String: Any])?["Labels"] as? [String: String] ?? [:]
            containers[index].composeProject = labels["com.docker.compose.project"]
            containers[index].workingDirectory = labels["com.docker.compose.project.working_dir"]
            containers[index].bindMounts = (row["Mounts"] as? [[String: Any]] ?? []).filter { $0["Type"] as? String == "bind" }.compactMap { $0["Source"] as? String }
            let ports = (row["NetworkSettings"] as? [String: Any])?["Ports"] as? [String: Any] ?? [:]
            containers[index].ports = ports.flatMap { key, value -> [DockerPublishedPort] in
                let parts = key.split(separator: "/").map(String.init)
                guard parts.count == 2 else { return [] }
                return (value as? [[String: String]] ?? []).map { binding in
                    DockerPublishedPort(hostIP: binding["HostIp"] ?? "", hostPort: binding["HostPort"] ?? "", containerPort: parts[0], transport: parts.count > 1 ? parts[1] : "tcp")
                }
            }.sorted { ($0.hostPort, $0.hostIP) < ($1.hostPort, $1.hostIP) }
        }
    }
    static func applyStats(_ output: String, to containers: inout [DockerContainer]) throws {
        for row in try jsonRows(output) {
            guard let id = (row["ID"] ?? row["Container"]) as? String,
                  let index = containers.firstIndex(where: { $0.id == id || $0.id.hasPrefix(id) }) else { continue }
            containers[index].cpuPercent = (row["CPUPerc"] as? String).flatMap { Double($0.replacingOccurrences(of: "%", with: "")) }
            containers[index].memoryUsage = row["MemUsage"] as? String
            containers[index].memoryBytes = (row["MemUsage"] as? String).flatMap { memoryBytes(String($0.split(separator: "/").first ?? "")) }
        }
    }
    static func memoryBytes(_ value: String) -> Double? {
        let text = value.trimmingCharacters(in: .whitespaces)
        let number = text.prefix { $0.isNumber || $0 == "." }
        guard let amount = Double(number) else { return nil }
        let suffix = text.dropFirst(number.count).trimmingCharacters(in: .whitespaces).lowercased()
        let units: [String: Double] = ["b": 1, "kb": 1e3, "mb": 1e6, "gb": 1e9, "tb": 1e12, "kib": 1024, "mib": 1048576, "gib": 1073741824, "tib": 1099511627776]
        return units[suffix].map { amount * $0 }
    }
    private static func jsonRows(_ output: String) throws -> [[String: Any]] {
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return [] }
        if text.hasPrefix("[") {
            guard let rows = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [[String: Any]] else { throw Failure(message: "docker.error.output".localized) }
            return rows
        }
        return try text.split(separator: "\n").map { line in
            guard let row = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { throw Failure(message: "docker.error.output".localized) }
            return row
        }
    }

    private static func command(_ arguments: [String], directory: URL? = nil, input: String? = nil, timeout: TimeInterval = 30, requireSuccess: Bool = true) throws -> CommandResult {
        guard let path = cliPath() else { throw Failure(message: "docker.error.cli".localized) }
        return try run(executable: path, arguments: arguments, directory: directory, input: input, timeout: timeout, requireSuccess: requireSuccess)
    }

    static func run(executable: String, arguments: [String], directory: URL? = nil, input: String? = nil, timeout: TimeInterval = 30, requireSuccess: Bool = true) throws -> CommandResult {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("devatlas-docker-\(UUID().uuidString)")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: folder) }
        let stdoutURL = folder.appendingPathComponent("stdout")
        let stderrURL = folder.appendingPathComponent("stderr")
        fm.createFile(atPath: stdoutURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        fm.createFile(atPath: stderrURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer { try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (environment["PATH"] ?? "")
        environment["NO_COLOR"] = "1"
        process.environment = environment
        process.standardOutput = stdout
        process.standardError = stderr
        var inputHandle: FileHandle?
        if let input {
            let url = folder.appendingPathComponent("stdin")
            try input.write(to: url, atomically: true, encoding: .utf8)
            inputHandle = try FileHandle(forReadingFrom: url)
            process.standardInput = inputHandle
        } else { process.standardInput = FileHandle.nullDevice }
        defer { try? inputHandle?.close() }
        let ended = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in ended.signal() }
        try process.run()
        if ended.wait(timeout: .now() + timeout) == .timedOut {
            if process.isRunning { process.terminate() }
            if ended.wait(timeout: .now() + 1) == .timedOut, process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
            throw Failure(message: "docker.error.timeout".localized)
        }
        // Read a bounded tail for potentially noisy build output.
        func read(_ url: URL) throws -> String {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let size = try handle.seekToEnd()
            try handle.seek(toOffset: size > 8_388_608 ? size - 8_388_608 : 0)
            return String(decoding: try handle.readToEnd() ?? Data(), as: UTF8.self)
        }
        let result = CommandResult(status: process.terminationStatus, output: try read(stdoutURL), error: try read(stderrURL))
        if requireSuccess, result.status != 0 {
            throw Failure(message: result.error.isEmpty ? (result.output.isEmpty ? "docker.error.command".localized : result.output) : result.error)
        }
        return result
    }
}
