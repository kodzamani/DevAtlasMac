// swiftc -parse-as-library DevAtlasMac/Models/DockerModels.swift DevAtlasMac/Services/Docker{Service,ComposeParser}.swift \
// DevAtlasMac/Services/PortProcessService.swift DevAtlasMac/Extensions/String+Localization.swift \
// DevAtlasMac/Enums/AppLanguage.swift Tests/DockerServiceTests.swift -o /tmp/devatlas-docker-tests && /tmp/devatlas-docker-tests
import Foundation

@main
struct DockerServiceTests {
    struct Failure: Error { let message: String }
    static func expect(_ value: Bool, _ message: String) throws {
        if !value { throw Failure(message: message) }
    }
    static func main() throws {
        let source = """
        # Keep this file's extensions and comments.
        name: local-app
        x-defaults:
          logging:
            driver: json-file
        services:
          api:
            image: 'example/api:1'
            command: ["run", "--debug"]
            ports:
              - "127.0.0.1:8080:80/tcp"
            environment:
              EMPTY: ""
              INHERITED:
              PASSWORD: "secret # literal: value"
            depends_on:
              database:
                condition: service_healthy
            healthcheck:
              test: ["CMD", "curl", "localhost"]
            deploy:
              resources:
                limits:
                  memory: 1G
          database:
            image: postgres:16-alpine
            volumes:
              - database_data:/var/lib/postgresql/data
        volumes:
          database_data:
            external: true
        networks:
          backend:
            external: true
        """ + "\n"
        var document = DockerComposeParser.parse(source)
        try expect(!document.visualUnavailable && document.services.count == 2, "Parse block services")
        try expect(try DockerComposeParser.serialize(document) == source, "Unedited source must round-trip byte for byte")
        try expect(document.services[0].lockedFields == ["command", "depends_on"], "Advanced known fields must be locked")
        try expect(document.services[0].environment[0].value == "" && document.services[0].environment[1].value == nil, "Empty vs inherited env")
        try expect(document.services[0].environment[2].value == "secret # literal: value", "Quoted colons and comments")
        try expect(document.services[0].ports.first?.hostIP == "127.0.0.1", "Host address in port mappings")
        document.services[0].image = "example/api:2"
        document.services[0].ports.append(.init(host: "8443", target: "443"))
        document.services.append(DockerServiceTemplate.redis.service(named: "cache"))
        let output = try DockerComposeParser.serialize(document)
        try expect(output.contains("external: true") && output.contains("condition: service_healthy") && output.contains("memory: 1G") && output.contains("command: [\"run\", \"--debug\"]"), "Preserve advanced and unknown blocks")
        try expect(output.contains("cache_data: {}") && output.contains("database_data:\n    external: true"), "New named volumes must not replace existing declarations")
        let reparsed = DockerComposeParser.parse(output)
        try expect(reparsed.services.count == 3 && reparsed.services[0].ports.count == 2 && reparsed.services.last?.name == "cache", "Reparse edited output")

        // All these additions share the end of the services block: their order matters.
        var boundary = DockerComposeParser.parse("services:\n  app:\n    image: alpine:3\n")
        boundary.services[0].environment = [.init(key: "MESSAGE", value: "hello\nworld")]
        boundary.services.append(DockerServiceTemplate.redis.service(named: "redis"))
        let boundaryOutput = try DockerComposeParser.serialize(boundary)
        let boundaryParsed = DockerComposeParser.parse(boundaryOutput)
        try expect(boundaryParsed.services.first?.environment.first?.key == "MESSAGE", "Append field before a new service")
        try expect(boundaryParsed.services.last?.image == "redis:7-alpine", "Append service before top-level volumes")
        try expect(boundaryParsed.services.first?.environment.first?.value == "hello\nworld", "Escape newlines in YAML strings")

        var empty = DockerComposeParser.parse("services: {}\n")
        try expect(!empty.visualUnavailable && empty.services.isEmpty, "Empty new document")
        empty.services.append(DockerServiceTemplate.postgres.service(named: "postgres"))
        let newOutput = try DockerComposeParser.serialize(empty)
        try expect(!DockerComposeParser.parse(newOutput).visualUnavailable && newOutput.contains("postgres_data: {}"), "Create services and volumes in empty document")
        var duplicate = document
        duplicate.services.append(duplicate.services[0])
        do { _ = try DockerComposeParser.serialize(duplicate); throw Failure(message: "Reject duplicate names") }
        catch is DockerComposeParser.Failure {}

        for advanced in ["services: {web: {image: nginx}}\n", "services:\n  web: &defaults\n    image: nginx\n", "services:\n  web:\n    <<: *defaults\n", "services:\n\tweb:\n\t\timage: nginx\n", "services:\n  web:\n    image: nginx\n    image: alpine\n"] {
            let parsed = DockerComposeParser.parse(advanced)
            try expect(parsed.visualUnavailable, "Unsupported root syntax uses YAML mode")
            try expect(try DockerComposeParser.serialize(parsed) == advanced, "Advanced source stays untouched")
        }
        let advancedFields = DockerComposeParser.parse("services:\n  web:\n    image: nginx\n    ports:\n      - target: 80\n        published: 8080\n    volumes:\n      - type: bind\n        source: .\n        target: /app\n    build:\n      context: .\n      args:\n        VERSION: 1\n")
        try expect(advancedFields.services.first?.lockedFields == ["ports", "volumes", "build"], "Long syntax and build args stay lossless")
        let lists = DockerComposeParser.parse("services:\n  app:\n    image: alpine\n    environment:\n      - KEY=value=more\n      - INHERIT\n    depends_on:\n      - db\n    env_file: .env\n    networks:\n      - backend\n")
        try expect(lists.services[0].environment.first?.value == "value=more" && lists.services[0].environment.last?.value == nil, "List environment")
        try expect(lists.services[0].dependencies == ["db"] && lists.services[0].envFiles == [".env"] && lists.services[0].networks == ["backend"], "Simple lists")

        var containers = try DockerService.parseContainers("{\"ID\":\"abcdefabcdef\",\"Names\":\"web\",\"Image\":\"nginx\",\"State\":\"running\",\"Status\":\"Up 2 hours\"}\n")
        try DockerService.applyInspection("""
        [{"Id":"abcdefabcdef","Config":{"Labels":{"com.docker.compose.project":"app","com.docker.compose.project.working_dir":"/tmp/My Project"}},"Mounts":[{"Type":"bind","Source":"/tmp/My Project/src"}],"NetworkSettings":{"Ports":{"80/tcp":[{"HostIp":"127.0.0.1","HostPort":"8080"}],"443/tcp":null}}}]
        """, to: &containers)
        try DockerService.applyStats("{\"ID\":\"abcdefabcdef\",\"CPUPerc\":\"1.25%\",\"MemUsage\":\"12.5MiB / 8GiB\"}\n", to: &containers)
        try expect(containers[0].ports.first?.hostPort == "8080" && containers[0].cpuPercent == 1.25 && containers[0].memoryBytes == 13_107_200, "Inspection, ports and stats")
        try expect(containers[0].projectPath(in: ["/tmp/My Project", "/tmp/My Project/src"]) == "/tmp/My Project/src", "Most specific project matching")
        try expect(DockerService.memoryBytes("1.5GB") == 1_500_000_000 && DockerService.memoryBytes("2GiB") == 2_147_483_648, "Docker memory units")
        try expect(DockerService.shellQuote("a'b $(touch /tmp/no)") == "'a'\\''b $(touch /tmp/no)'", "Terminal command quoting")
        do { _ = try DockerService.parseContainers("not JSON"); throw Failure(message: "Reject malformed CLI output") }
        catch is Failure { throw Failure(message: "Reject malformed CLI output") }
        catch {}

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Docker Tests \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "services: {}\n".write(to: directory.appendingPathComponent("compose.yaml"), atomically: true, encoding: .utf8)
        let stacks = DockerService.discoverStacks(projects: [(id: "project", name: "Test Project", path: directory.path)])
        try expect(stacks.count == 1 && stacks[0].projectName == "Test Project", "Discover stacks even with no running containers")
        let echo = try DockerService.run(executable: "/bin/cat", arguments: [], directory: directory, input: "YAML with spaces\n")
        try expect(echo.output == "YAML with spaces\n", "stdin transport")
        let noisy = try DockerService.run(executable: "/usr/bin/perl", arguments: ["-e", "print 'x' x 100000; print STDERR 'y' x 100000; exit 7"], requireSuccess: false)
        try expect(noisy.status == 7 && noisy.output.count == 100000 && noisy.error.count == 100000, "Concurrent large stdout/stderr cannot deadlock")
        let start = Date()
        do { _ = try DockerService.run(executable: "/bin/sleep", arguments: ["10"], timeout: 0.1); throw Failure(message: "Timeout must fail") }
        catch is DockerService.Failure {}
        try expect(Date().timeIntervalSince(start) < 3, "Timeout terminates the child promptly")
        if DockerService.cliPath() != nil {
            // config is read-only and does not require a daemon or download/start any containers.
            try DockerService.validate(boundaryOutput, fileURL: directory.appendingPathComponent("compose.yaml"))
            for template in DockerServiceTemplate.allCases {
                var draft = DockerComposeParser.parse("services: {}\n")
                draft.services.append(template.service(named: template.rawValue))
                var yaml = try DockerComposeParser.serialize(draft)
                // Resolve required preset credentials in the isolated test input only.
                for key in ["POSTGRES_PASSWORD", "MYSQL_ROOT_PASSWORD", "MINIO_ROOT_PASSWORD", "PGADMIN_DEFAULT_PASSWORD"] {
                    yaml = yaml.replacingOccurrences(of: "${\(key):?Set \(key) in .env}", with: "test-password-123")
                }
                try DockerService.validate(yaml, fileURL: directory.appendingPathComponent("compose.yaml"))
            }
        }
        if let image = ProcessInfo.processInfo.environment["DEVATLAS_DOCKER_LIVE_TEST_IMAGE"], let cli = DockerService.cliPath() {
            // Opt-in smoke test: use only a local image, an isolated network, and transient tmpfs mounts.
            // All lifecycle actions target this unique disposable container, never an existing one.
            let metadata = try DockerService.run(executable: cli, arguments: ["image", "inspect", "--format", "{{json .Config.Volumes}}", image])
            let volumePaths = ((try JSONSerialization.jsonObject(with: Data(metadata.output.utf8), options: .fragmentsAllowed)) as? [String: Any] ?? [:]).keys.sorted()
            let tmpfs = volumePaths.flatMap { ["--tmpfs", $0] }
            let created = try DockerService.run(executable: cli, arguments: ["create", "--pull", "never", "--network", "none"] + tmpfs + ["--name", "devatlas-smoke-" + UUID().uuidString.lowercased(), "--entrypoint", "/bin/sh", image, "-c", "trap 'exit 0' TERM; echo devatlas-smoke; while :; do sleep 1 & wait $!; done"])
            let id = created.output.trimmingCharacters(in: .whitespacesAndNewlines)
            defer {
                try? DockerService.perform(.stop, containerID: id)
                try? DockerService.perform(.remove, containerID: id)
            }
            try DockerService.perform(.start, containerID: id)
            let live = try DockerService.snapshot()
            try expect(live.state == .running && live.containers.contains { $0.id == id && $0.isRunning }, "Live start and snapshot")
            try expect(try DockerService.logs(containerID: id).contains("devatlas-smoke"), "Live logs")
            try DockerService.perform(.restart, containerID: id)
            try DockerService.perform(.stop, containerID: id)
            try expect(try DockerService.snapshot().containers.contains { $0.id == id && $0.state == "exited" }, "Live restart and stop")
            try DockerService.perform(.remove, containerID: id)
            try expect(try !DockerService.snapshot().containers.contains { $0.id == id }, "Live remove")
            print("Docker live smoke: isolated disposable container start, stats, logs, restart, stop and remove passed.")
        }
        print("Docker: lossless YAML, advanced syntax, presets, CLI JSON, matching, stack discovery, stdin, large output and timeout checks passed.")
    }
}
