import Foundation
import Darwin

struct PortListener: Identifiable, Codable, Hashable, Sendable {
    var pid: Int32
    var command: String
    var port: Int
    var address: String
    var workingDirectory: String?
    var startedAt: String?
    var id: String { "\(pid):\(address)" }
    var browserURL: URL? { URL(string: "http://localhost:\(port)") }
}

/// Uses lsof's field output so command names and directories containing spaces stay intact.
enum PortProcessService {
    enum Failure: LocalizedError {
        case scan, stale, signal(Int32)
        var errorDescription: String? {
            switch self {
            case .scan: return "ports.error.scan".localized
            case .stale: return "ports.error.stale".localized
            case .signal(let code): return "ports.error.signal".localized(String(cString: strerror(code)))
            }
        }
    }

    static func scan() throws -> [PortListener] {
        let result = try run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"])
        // lsof returns 1 when there are no matching files.
        guard result.status == 0 || (result.status == 1 && result.output.isEmpty) else { throw Failure.scan }
        var listeners = parseListeners(result.output)
        let pids = Set(listeners.map(\.pid)).sorted()
        guard !pids.isEmpty else { return [] }
        let directories = try run("/usr/sbin/lsof", ["-a", "-p", pids.map(String.init).joined(separator: ","), "-d", "cwd", "-Fn"])
        let cwd = parseDirectories(directories.output)
        let starts = Dictionary(uniqueKeysWithValues: pids.compactMap { pid in
            startTime(pid).map { (pid, $0) }
        })
        for index in listeners.indices {
            listeners[index].workingDirectory = cwd[listeners[index].pid]
            listeners[index].startedAt = starts[listeners[index].pid]
        }
        return listeners.sorted { ($0.port, $0.pid, $0.address) < ($1.port, $1.pid, $1.address) }
    }

    static func terminate(_ listener: PortListener) throws {
        guard listener.pid > 1, listener.pid != getpid(), let started = listener.startedAt,
              startTime(listener.pid) == started,
              let current = try scan().first(where: { $0.id == listener.id }),
              current.startedAt == started, current.command == listener.command,
              current.workingDirectory == listener.workingDirectory else { throw Failure.stale }
        guard kill(listener.pid, SIGTERM) == 0 else { throw Failure.signal(errno) }
    }

    static func matchingPath(for directory: String?, projectPaths: [String]) -> String? {
        guard let directory else { return nil }
        let cwd = URL(fileURLWithPath: directory).resolvingSymlinksInPath().standardizedFileURL.path
        return projectPaths.map { path in
            (path: path, root: URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path)
        }.filter { candidate in
            cwd == candidate.root || cwd.hasPrefix(candidate.root == "/" ? candidate.root : candidate.root + "/")
        }.max { $0.root.count < $1.root.count }?.path
    }

    static func parseListeners(_ output: String) -> [PortListener] {
        var pid: Int32?
        var command = ""
        var rows: [String: PortListener] = [:]
        for line in output.split(separator: "\n") {
            let value = String(line.dropFirst())
            switch line.first {
            case "p": pid = Int32(value); command = ""
            case "c": command = value
            case "n":
                guard let pid, let last = value.split(separator: ":").last,
                      let port = Int(last), (1...65535).contains(port) else { continue }
                let row = PortListener(pid: pid, command: command, port: port, address: value)
                rows[row.id] = row
            default: break
            }
        }
        return Array(rows.values)
    }

    static func parseDirectories(_ output: String) -> [Int32: String] {
        var pid: Int32?
        var directories: [Int32: String] = [:]
        for line in output.split(separator: "\n") {
            if line.first == "p" { pid = Int32(line.dropFirst()) }
            if line.first == "n", let pid { directories[pid] = String(line.dropFirst()) }
        }
        return directories
    }

    private static func startTime(_ pid: Int32) -> String? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return "\(info.pbi_start_tvsec):\(info.pbi_start_tvusec)"
    }

    private static func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        defer { try? pipe.fileHandleForReading.close() }
        try process.run()
        // Bound each subprocess; reading the pipe before waiting avoids a full-pipe deadlock.
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeout)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
