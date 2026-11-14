// Compile with Docker models/services, ProjectInfo, ProjectCategory, DockerViewModel and localization helpers.
import Foundation

@main
struct DockerViewModelTests {
    struct Failure: Error { let message: String }
    static func expect(_ value: Bool, _ message: String) throws { if !value { throw Failure(message: message) } }

    @MainActor
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DevAtlas Draft Tests \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let project = ProjectInfo(name: "Draft Tests", path: directory.path, projectType: "Docker", category: .cloud, tags: [], lastModified: Date(), isActive: true)
        let stack = DockerComposeStack(projectID: project.id, projectName: project.name, fileURL: directory.appendingPathComponent("compose.yaml"))
        let manager = DockerViewModel()
        manager.open(stack)
        try expect(manager.activeStack == stack && manager.isDirty, "New file is an unsaved draft")
        try expect(!FileManager.default.fileExists(atPath: stack.fileURL.path), "Opening a new Compose must not write a file")
        manager.addService(.redis)
        manager.addService(.redis)
        try expect(manager.document?.services.map(\.name) == ["redis", "redis2"], "Unique template service names")
        var service = manager.selectedService!
        let portID = service.ports[0].id
        let serviceID = service.id
        service.ports[0].host = "6380"
        manager.updateService(service)
        try expect(manager.yaml.contains("6380:6379") && manager.selectedService?.ports.first?.id == portID, "Visual edits update YAML and retain field identity")
        manager.setYAML(manager.yaml.replacingOccurrences(of: "redis:7-alpine", with: "redis:7"))
        try expect(manager.selectedService?.image == "redis:7" && manager.selectedServiceID == serviceID, "YAML edits update form while retaining service selection")
        var first = manager.document!.services[0]
        first.dependencies = [manager.selectedService!.name]
        manager.updateService(first)
        service = manager.document!.services[1]
        service.name = "cache"
        manager.updateService(service)
        try expect(manager.document?.services[0].dependencies == ["cache"], "Renaming a new service updates visual dependencies")
        let other = DockerComposeStack(projectID: project.id, projectName: project.name, fileURL: directory.appendingPathComponent("other.yaml"))
        manager.requestOpen(other)
        try expect(manager.pendingStack == other && manager.activeStack == stack, "Unsaved changes require a discard decision before switching")
        manager.pendingStack = nil
        manager.revert()
        try expect(manager.document?.services.isEmpty == true, "Revert new draft")
        manager.addService(.redis)
        // Avoid two services competing for the same port; no containers are started by these checks.
        if DockerService.cliPath() != nil {
            await manager.validate()
            try expect(manager.validationSucceeded && !FileManager.default.fileExists(atPath: stack.fileURL.path), "Validate draft without writing it")
            await manager.save(apply: false, projects: [project])
            try expect(!manager.isDirty && manager.validationSucceeded && manager.busyIDs.isEmpty && !manager.isSaving, "Validated save settles state")
            try expect(try String(contentsOf: stack.fileURL, encoding: .utf8) == manager.yaml, "Save exact draft bytes")
            try expect(manager.stacks.contains { $0.id == stack.id }, "New file enters stack discovery")
            let external = "# external editor\n" + manager.yaml
            try external.write(to: stack.fileURL, atomically: true, encoding: .utf8)
            service = manager.selectedService!
            service.image = "redis:7"
            manager.updateService(service)
            await manager.save(apply: false, projects: [project])
            try expect(!manager.validationSucceeded && manager.isDirty, "External write causes save conflict")
            try expect(try String(contentsOf: stack.fileURL, encoding: .utf8) == external, "Never overwrite externally changed source")
            manager.requestOpen(stack)
            try expect(manager.pendingStack == stack, "Same-file reload can recover from an external-write conflict")
            manager.open(stack)
            try expect(manager.yaml == external && !manager.isDirty, "Explicit reload reads current disk contents")
            manager.setYAML("services: [not valid compose")
            await manager.save(apply: false, projects: [project])
            try expect(!manager.validationSucceeded && manager.isDirty, "Invalid Compose is rejected")
            try expect(try String(contentsOf: stack.fileURL, encoding: .utf8) == external, "Validation failure leaves disk untouched")
        }
        if let image = ProcessInfo.processInfo.environment["DEVATLAS_DOCKER_LIVE_TEST_IMAGE"], let cli = DockerService.cliPath() {
            let metadata = try DockerService.run(executable: cli, arguments: ["image", "inspect", "--format", "{{json .Config.Volumes}}", image])
            let volumePaths = ((try JSONSerialization.jsonObject(with: Data(metadata.output.utf8), options: .fragmentsAllowed)) as? [String: Any] ?? [:]).keys.sorted()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            let tmpfs = String(data: try encoder.encode(volumePaths), encoding: .utf8)!
            let imageLiteral = String(data: try encoder.encode(image), encoding: .utf8)!
            let smoke = """
            name: devatlas-smoke-\(UUID().uuidString.lowercased())
            services:
              smoke:
                image: \(imageLiteral)
                pull_policy: never
                network_mode: none
                tmpfs: \(tmpfs)
                entrypoint: ["/bin/sh", "-c"]
                command: ["trap 'exit 0' TERM; echo compose-smoke; while :; do sleep 1 & wait $!; done"]
            """ + "\n"
            defer { try? DockerService.compose(.down, fileURL: stack.fileURL) }
            manager.setYAML(smoke)
            await manager.save(apply: true, projects: [project])
            try expect(manager.validationSucceeded && !manager.isDirty && manager.busyIDs.isEmpty, "Save & Apply settles state")
            let ownContainers = manager.containers.filter { $0.workingDirectory == directory.path }
            try expect(ownContainers.count == 1 && ownContainers[0].isRunning, "Compose up starts the isolated test service")
            try expect(ownContainers[0].projectPath(in: [project.path]) == project.path, "Compose labels match the DevAtlas project")
            await manager.perform(.down, on: stack, projects: [project])
            try expect(!manager.containers.contains { $0.workingDirectory == directory.path } && !manager.isBusy(stack), "Compose down removes only this test stack and settles state")
            print("Docker Compose live smoke: Save & Apply, stack up/down, label matching and operation state passed.")
        }
        print("DockerViewModel: draft creation, unique presets, bidirectional editing, identity, unsaved navigation, validation, atomic save and external-write conflict checks passed.")
    }
}
