// swiftc -parse-as-library DevAtlasMac/Services/PortProcessService.swift \
//   DevAtlasMac/Extensions/String+Localization.swift DevAtlasMac/Enums/AppLanguage.swift \
//   Tests/PortProcessServiceTests.swift -o /tmp/devatlas-ports-tests && /tmp/devatlas-ports-tests
import Foundation
import Darwin

@main
struct PortProcessServiceTests {
    struct Failure: Error { let message: String }
    static func expect(_ value: Bool, _ message: String) throws {
        if !value { throw Failure(message: message) }
    }

    static func main() throws {
        let parsed = PortProcessService.parseListeners("p42\ncnode server\nf12\nn127.0.0.1:3000\nf13\nn[::1]:3000\nf14\nn[::1]:3000\np43\ncpython\nn*:8080\nninvalid\nn*:99999\n")
        try expect(parsed.count == 3, "IPv4, IPv6, wildcard and duplicate endpoints")
        try expect(parsed.contains { $0.pid == 42 && $0.command == "node server" && $0.port == 3000 }, "Command names with spaces")
        let directories = PortProcessService.parseDirectories("p42\nfcwd\nn/Users/dev/My Project/web\np43\nfcwd\nn/tmp\n")
        try expect(directories[42] == "/Users/dev/My Project/web", "Directories with spaces")
        try expect(PortProcessService.matchingPath(for: "/tmp/app/web/src", projectPaths: ["/tmp/app", "/tmp/app/web"]) == "/tmp/app/web", "Most specific project")
        try expect(PortProcessService.matchingPath(for: "/tmp/application", projectPaths: ["/tmp/app"]) == nil, "Directory boundary")
        try expect(PortProcessService.matchingPath(for: nil, projectPaths: ["/tmp"]) == nil, "Missing directory")
        try expect(PortProcessService.parseListeners("").isEmpty, "Empty output")

        // Start only our own disposable server; SIGTERM must never target an unrelated process.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DevAtlas port test \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let alias = directory.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(atPath: alias.path, withDestinationPath: directory.path)
        try expect(PortProcessService.matchingPath(for: alias.path, projectPaths: [directory.path]) == directory.path, "Symlink resolution")
        let server = Process()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        server.arguments = ["-MIO::Socket::INET", "-e", "my $s = IO::Socket::INET->new(LocalAddr=>'127.0.0.1',LocalPort=>0,Listen=>1,ReuseAddr=>1) or die $!; $|=1; print $s->sockport, qq(\\n); sleep 60;"]
        server.currentDirectoryURL = directory
        let output = Pipe()
        server.standardOutput = output
        server.standardError = FileHandle.nullDevice
        try server.run()
        defer {
            if server.isRunning { server.terminate() }
            server.waitUntilExit()
            try? output.fileHandleForReading.close()
        }
        var portData = Data()
        while true {
            let byte = output.fileHandleForReading.readData(ofLength: 1)
            if byte.isEmpty || byte == Data([10]) { break }
            portData.append(byte)
        }
        guard let port = Int(String(decoding: portData, as: UTF8.self)),
              let listener = try PortProcessService.scan().first(where: { $0.pid == server.processIdentifier && $0.port == port }) else {
            throw Failure(message: "Live listener discovery")
        }
        try expect(PortProcessService.matchingPath(for: listener.workingDirectory, projectPaths: [directory.path]) == directory.path, "Live working directory with spaces")
        try expect(listener.startedAt != nil, "Process creation identity")
        var stale = listener
        stale.startedAt = "invalid"
        do {
            try PortProcessService.terminate(stale)
            throw Failure(message: "Stale identity must be rejected")
        } catch PortProcessService.Failure.stale {}
        try expect(server.isRunning, "Stale action must leave process running")
        try PortProcessService.terminate(listener)
        server.waitUntilExit()
        try expect(server.terminationReason == .uncaughtSignal && server.terminationStatus == SIGTERM, "Graceful termination")
        try expect(!(try PortProcessService.scan()).contains { $0.pid == server.processIdentifier }, "Stopped process disappears")
        print("PortProcessService: parser, matching, live scan, stale identity and SIGTERM checks passed.")
    }
}
