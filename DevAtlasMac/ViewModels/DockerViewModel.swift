import Foundation
import Combine

@MainActor
final class DockerViewModel: ObservableObject {
    nonisolated init() {}

    enum Mode: String, CaseIterable, Identifiable {
        case containers, composeStudio
        var id: String { rawValue }
        var title: String { "docker.mode.\(rawValue)".localized }
    }
    enum Filter: String, CaseIterable, Identifiable {
        case all, running, project, standalone
        var id: String { rawValue }
        var title: String { "docker.filter.\(rawValue)".localized }
    }
    @Published var mode: Mode = .containers
    @Published var filter: Filter = .all
    @Published private(set) var state: DockerDaemonState?
    @Published private(set) var containers: [DockerContainer] = []
    @Published private(set) var stacks: [DockerComposeStack] = []
    @Published private(set) var runtimes: [DockerRuntime] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var isStarting = false
    @Published private(set) var busyIDs: Set<String> = []
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published private(set) var scanMessage: String?
    @Published private(set) var activeStack: DockerComposeStack?
    @Published private(set) var document: DockerComposeDocument?
    @Published private(set) var yaml = ""
    @Published private(set) var savedSource: String?
    @Published private(set) var visualError: String?
    @Published private(set) var validationMessage: String?
    @Published private(set) var validationSucceeded = false
    @Published private(set) var isSaving = false
    @Published var selectedServiceID: UUID?
    @Published var isYAMLMode = false
    @Published var pendingStack: DockerComposeStack?
    var isDirty: Bool { activeStack != nil && (savedSource == nil || yaml != savedSource || visualError != nil) }
    var runningCount: Int { containers.filter(\.isRunning).count }
    var totalCPU: Double? {
        let values = containers.filter(\.isRunning).compactMap(\.cpuPercent)
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    var totalMemory: String? {
        let values = containers.filter(\.isRunning).compactMap(\.memoryBytes)
        guard !values.isEmpty else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(values.reduce(0, +)), countStyle: .memory)
    }
    var selectedService: DockerComposeService? { document?.services.first { $0.id == selectedServiceID } }

    func refresh(projects: [ProjectInfo]) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let paths = projects.map { (id: $0.id, name: $0.name, path: $0.path) }
        let result = await Task.detached(priority: .utility) {
            (DockerService.discoverStacks(projects: paths), Result { try DockerService.snapshot() })
        }.value
        stacks = result.0
        switch result.1 {
        case .success(let snapshot):
            state = snapshot.state; containers = snapshot.containers; runtimes = snapshot.runtimes
            scanMessage = snapshot.warning; lastUpdated = Date()
        case .failure(let error): scanMessage = error.localizedDescription
        }
    }

    func dismissError() { errorMessage = nil; scanMessage = nil }

    func perform(_ action: DockerContainerAction, on container: DockerContainer, projects: [ProjectInfo]) async {
        guard busyIDs.insert(container.id).inserted else { return }
        defer { busyIDs.remove(container.id) }
        let result = await Task.detached(priority: .userInitiated) { Result { try DockerService.perform(action, containerID: container.id) } }.value
        switch result {
        case .success: await refresh(projects: projects)
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }
    func isBusy(_ stack: DockerComposeStack) -> Bool {
        busyIDs.contains(stack.id) || busyIDs.contains("project:" + stack.projectID)
    }
    func perform(_ action: DockerStackAction, on stack: DockerComposeStack, projects: [ProjectInfo]) async {
        guard !isBusy(stack) else { return }
        busyIDs.insert(stack.id)
        busyIDs.insert("project:" + stack.projectID)
        defer { busyIDs.remove(stack.id); busyIDs.remove("project:" + stack.projectID) }
        let result = await Task.detached(priority: .userInitiated) { Result { try DockerService.compose(action, fileURL: stack.fileURL) } }.value
        switch result {
        case .success: await refresh(projects: projects)
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }
    func start(_ runtime: DockerRuntime, projects: [ProjectInfo]) async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        let result = await Task.detached(priority: .userInitiated) { Result { try DockerService.startRuntime(runtime) } }.value
        switch result {
        case .success:
            for _ in 0..<30 {
                await refresh(projects: projects)
                if state == .running { return }
                do { try await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000)) } catch { return }
            }
            errorMessage = "docker.error.starting".localized
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }
    func shell(_ container: DockerContainer) async {
        let result = await Task.detached { Result { try DockerService.openShell(containerID: container.id) } }.value
        if case .failure(let error) = result { errorMessage = error.localizedDescription }
    }

    func requestOpen(_ stack: DockerComposeStack) {
        guard !isSaving else { return }
        mode = .composeStudio
        if isDirty { pendingStack = stack } else { open(stack) }
    }
    func open(_ stack: DockerComposeStack) {
        guard !isSaving else { return }
        do {
            let exists = FileManager.default.fileExists(atPath: stack.fileURL.path)
            let source = exists ? try String(contentsOf: stack.fileURL, encoding: .utf8) : "services: {}\n"
            activeStack = stack; savedSource = exists ? source : nil
            setYAML(source)
            selectedServiceID = document?.services.first?.id
            isYAMLMode = document?.visualUnavailable == true
            validationMessage = nil; visualError = nil; pendingStack = nil
            mode = .composeStudio
        } catch { errorMessage = error.localizedDescription }
    }
    func revert() {
        guard !isSaving else { return }
        setYAML(savedSource ?? "services: {}\n")
        selectedServiceID = document?.services.first?.id
    }
    func setYAML(_ source: String) {
        guard !isSaving else { return }
        let previous = document?.services ?? []
        var parsed = DockerComposeParser.parse(source)
        for index in parsed.services.indices {
            if let old = previous.first(where: { $0.name == parsed.services[index].name }) { parsed.services[index].id = old.id }
        }
        parsed.originalServices = parsed.services
        yaml = source; document = parsed; visualError = nil; validationMessage = nil; validationSucceeded = false
        if !parsed.services.contains(where: { $0.id == selectedServiceID }) { selectedServiceID = parsed.services.first?.id }
    }
    func updateService(_ service: DockerComposeService) {
        guard !isSaving, var document, let index = document.services.firstIndex(where: { $0.id == service.id }) else { return }
        // Renaming a referenced service can also affect advanced depends_on, links and extension blocks.
        // Existing names stay stable in the visual form; the YAML editor supports arbitrary renames.
        let oldName = document.services[index].name
        document.services[index] = service
        if oldName != service.name {
            for otherIndex in document.services.indices where !document.services[otherIndex].lockedFields.contains("depends_on") {
                document.services[otherIndex].dependencies = document.services[otherIndex].dependencies.map { $0 == oldName ? service.name : $0 }
            }
        }
        self.document = document
        synchronizeVisual()
    }
    func addService(_ template: DockerServiceTemplate) {
        guard !isSaving, var document, !document.visualUnavailable else { return }
        var name = template.rawValue == "custom" ? "service" : template.rawValue
        let base = name
        var suffix = 2
        while document.services.contains(where: { $0.name == name }) { name = "\(base)\(suffix)"; suffix += 1 }
        let service = template.service(named: name)
        document.services.append(service); self.document = document
        selectedServiceID = service.id
        synchronizeVisual()
    }
    private func synchronizeVisual() {
        guard let document else { return }
        do { yaml = try DockerComposeParser.serialize(document); visualError = nil }
        catch { visualError = error.localizedDescription }
        validationMessage = nil; validationSucceeded = false
    }
    func validate() async {
        guard !isSaving, let stack = activeStack, visualError == nil else { return }
        isSaving = true
        defer { isSaving = false }
        let source = yaml
        let result = await Task.detached { Result { try DockerService.validate(source, fileURL: stack.fileURL) } }.value
        switch result {
        case .success: validationMessage = "docker.validation.success".localized; validationSucceeded = true
        case .failure(let error): validationMessage = error.localizedDescription; validationSucceeded = false
        }
    }
    func save(apply: Bool, projects: [ProjectInfo]) async {
        guard !isSaving, let stack = activeStack, visualError == nil, !isBusy(stack) else { return }
        isSaving = true
        busyIDs.insert(stack.id)
        busyIDs.insert("project:" + stack.projectID)
        defer { isSaving = false; busyIDs.remove(stack.id); busyIDs.remove("project:" + stack.projectID) }
        let source = yaml
        let original = savedSource
        let result = await Task.detached(priority: .userInitiated) {
            Result {
                try DockerService.validate(source, fileURL: stack.fileURL)
                let exists = FileManager.default.fileExists(atPath: stack.fileURL.path)
                let current = exists ? try String(contentsOf: stack.fileURL, encoding: .utf8) : nil
                guard current == original else { throw DockerService.Failure(message: "docker.error.fileChanged".localized) }
                try source.write(to: stack.fileURL, atomically: true, encoding: .utf8)
            }
        }.value
        switch result {
        case .success:
            savedSource = source; validationSucceeded = true; validationMessage = "docker.saved".localized
            if apply {
                let applied = await Task.detached(priority: .userInitiated) { Result { try DockerService.compose(.up, fileURL: stack.fileURL) } }.value
                if case .failure(let error) = applied { validationMessage = "docker.savedApplyFailed".localized + "\n" + error.localizedDescription; validationSucceeded = false }
            }
            await refresh(projects: projects)
        case .failure(let error): validationMessage = error.localizedDescription; validationSucceeded = false
        }
    }
}
