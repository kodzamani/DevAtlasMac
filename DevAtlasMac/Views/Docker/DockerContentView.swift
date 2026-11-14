import SwiftUI
import AppKit

struct DockerContentView: View {
    let viewModel: AppViewModel
    @State private var logsContainer: DockerContainer?
    @State private var removingContainer: DockerContainer?
    @State private var stoppingStack: DockerComposeStack?
    private var manager: DockerViewModel { viewModel.dockerManager }

    var body: some View {
        // Keep this screen's ideal size from enlarging the split view and shifting its sidebar.
        GeometryReader { geometry in
            content
                .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 16)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .task(id: viewModel.projects.map(\.path)) {
            while !Task.isCancelled {
                await manager.refresh(projects: viewModel.projects)
                do { try await Task.sleep(for: .seconds(8)) } catch { break }
            }
        }
        .sheet(item: $logsContainer) { DockerLogsSheet(container: $0) }
        .confirmationDialog("docker.remove.title".localized, isPresented: Binding(get: { removingContainer != nil }, set: { if !$0 { removingContainer = nil } }), titleVisibility: .visible) {
            if let container = removingContainer {
                Button("docker.action.remove".localized, role: .destructive) {
                    Task { await manager.perform(.remove, on: container, projects: viewModel.projects) }
                }
            }
        } message: { Text("docker.remove.detail".localized(removingContainer?.name ?? "")) }
        .confirmationDialog("docker.down.title".localized, isPresented: Binding(get: { stoppingStack != nil }, set: { if !$0 { stoppingStack = nil } }), titleVisibility: .visible) {
            if let stack = stoppingStack {
                Button("docker.stack.down".localized, role: .destructive) {
                    Task { await manager.perform(.down, on: stack, projects: viewModel.projects) }
                }
            }
        } message: { Text("docker.down.detail".localized(stoppingStack?.projectName ?? "")) }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            metrics
            if let error = manager.errorMessage ?? manager.scanMessage, !error.isEmpty {
                DockerBanner(kind: .warning, tint: .orange, text: error) {
                    DockerIconButton(kind: .xmark, help: "docker.dismiss".localized, size: 20) { manager.dismissError() }
                }
            }
            if manager.state != .running { daemonNotice }
            if manager.mode == .containers {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        containersSection
                        stacksSection
                    }
                    .padding(.top, 4).padding(.bottom, 12)
                }
                .scrollIndicators(.automatic)
            } else {
                DockerComposeEditorView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            DockerIconTile(kind: .whale, tint: .daDocker, size: 44, filled: true)
            VStack(alignment: .leading, spacing: 3) {
                Text("tab.docker".localized)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Text("docker.subtitle".localized)
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 7) {
                    DockerStatusDot(color: manager.state?.color ?? .secondary, isLive: manager.state == .running, size: 6)
                    Text(manager.state?.title ?? "docker.connecting".localized)
                    if !manager.runtimes.isEmpty {
                        Text(manager.runtimes.map(\.name).joined(separator: " · ")).foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.primary.opacity(0.05), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.06)))
                if let date = manager.lastUpdated {
                    HStack(spacing: 4) {
                        if manager.isRefreshing { ProgressView().controlSize(.mini) }
                        else { DockerIcon(.clock, size: 10) }
                        Text("ports.updated".localized) + Text(date, style: .time)
                    }
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: Metrics

    private var metrics: some View {
        let loaded = manager.lastUpdated != nil
        return HStack(spacing: 0) {
            DockerMetric(kind: .power, tint: manager.state?.color ?? .secondary, label: "docker.daemon".localized,
                         value: manager.state?.title)
            StatStripDivider()
            DockerMetric(kind: .container, tint: .daDocker, label: "docker.containers".localized,
                         value: loaded ? "\(manager.runningCount) / \(manager.containers.count)" : nil,
                         footnote: "docker.runningTotal".localized)
            StatStripDivider()
            DockerMetric(kind: .stack, tint: .purple, label: "docker.stacks".localized,
                         value: "\(Set(manager.stacks.map(\.projectID)).count)")
            StatStripDivider()
            DockerMetric(kind: .cpu, tint: .orange, label: "docker.cpu".localized,
                         value: loaded ? (manager.totalCPU.map { String(format: "%.1f%%", $0) } ?? "—") : nil)
            StatStripDivider()
            DockerMetric(kind: .memory, tint: .teal, label: "docker.memory".localized,
                         value: loaded ? (manager.totalMemory ?? "—") : nil)
        }
        .fixedSize(horizontal: false, vertical: true)
        .daCardSurface()
    }

    private var daemonNotice: some View {
        HStack(spacing: 12) {
            DockerIconTile(kind: .power, tint: manager.state?.color ?? .secondary, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.state?.title ?? "docker.connecting".localized).font(.system(size: 13, weight: .semibold))
                Text("docker.daemon.detail".localized).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            if manager.isStarting {
                ProgressView().controlSize(.small)
            } else if manager.runtimes.count == 1, let runtime = manager.runtimes.first {
                DockerActionButton(kind: .play, title: "docker.startDocker".localized, style: .prominent) {
                    Task { await manager.start(runtime, projects: viewModel.projects) }
                }
            } else if !manager.runtimes.isEmpty {
                Menu {
                    ForEach(manager.runtimes) { runtime in
                        Button(runtime.name) { Task { await manager.start(runtime, projects: viewModel.projects) } }
                    }
                } label: {
                    DockerActionLabel(kind: .play, title: "docker.startDocker".localized, style: .prominent)
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            }
        }
        .padding(12)
        .daCardSurface()
    }

    // MARK: Containers

    private var filteredContainers: [DockerContainer] {
        manager.containers.filter { container in
            let project = project(for: container)
            let matchesFilter: Bool
            switch manager.filter {
            case .all: matchesFilter = true
            case .running: matchesFilter = container.isRunning
            case .project: matchesFilter = project != nil
            case .standalone: matchesFilter = project == nil
            }
            return matchesFilter && matchesSearch([container.name, container.image, container.composeProject ?? "", project?.name ?? ""])
        }
    }

    private func matchesSearch(_ values: [String]) -> Bool {
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || values.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func project(for container: DockerContainer) -> ProjectInfo? {
        guard let path = container.projectPath(in: viewModel.projects.map(\.path)) else { return nil }
        return viewModel.projects.first { $0.path == path }
    }

    private static let grid = [GridItem(.adaptive(minimum: 330, maximum: 520), spacing: 10, alignment: .top)]

    private var containersSection: some View {
        let rows = filteredContainers
        return VStack(alignment: .leading, spacing: 10) {
            DockerSectionHeader(kind: .container, title: "docker.containers".localized, count: rows.count) {
                filterBar
            }
            if rows.isEmpty {
                DockerEmptyCard(kind: .container, text: "docker.emptyContainers".localized)
            } else {
                LazyVGrid(columns: Self.grid, spacing: 10) {
                    ForEach(rows) { container in
                        let project = project(for: container)
                        DockerContainerCard(
                            container: container, project: project, isBusy: manager.busyIDs.contains(container.id),
                            openProject: { if let project { viewModel.openProject(project) } },
                            action: { action in
                                if action == .remove { removingContainer = container }
                                else { Task { await manager.perform(action, on: container, projects: viewModel.projects) } }
                            },
                            logs: { logsContainer = container },
                            shell: { Task { await manager.shell(container) } })
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        @Bindable var manager = manager
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
                ForEach(DockerViewModel.Filter.allCases) { filter in
                    let isOn = manager.filter == filter
                    Button { manager.filter = filter } label: {
                        HStack(spacing: 5) {
                            DockerIcon(Self.icon(for: filter), size: 11)
                            Text(filter.title).lineLimit(1)
                        }
                        .font(.system(size: 11, weight: isOn ? .semibold : .medium))
                        .foregroundStyle(isOn ? Color.daPrimaryText : Color.daTertiaryText)
                        .padding(.horizontal, 9).frame(height: 24)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.background)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: manager.filter)

            Picker("docker.filter".localized, selection: $manager.filter) {
                ForEach(DockerViewModel.Filter.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden().fixedSize()
        }
    }

    private static func icon(for filter: DockerViewModel.Filter) -> DockerIcon.Kind {
        switch filter {
        case .all: .container
        case .running: .play
        case .project: .folder
        case .standalone: .image
        }
    }

    // MARK: Stacks

    private var stacksSection: some View {
        let stacks = manager.stacks.filter { matchesSearch([$0.projectName, $0.fileURL.path]) }
        return VStack(alignment: .leading, spacing: 10) {
            DockerSectionHeader(kind: .stack, title: "docker.stacks".localized, count: stacks.count)
            if stacks.isEmpty {
                DockerEmptyCard(kind: .compose, text: "docker.emptyStacks".localized)
            } else {
                LazyVGrid(columns: Self.grid, spacing: 10) {
                    ForEach(stacks) { stack in
                        DockerStackCard(
                            stack: stack,
                            project: viewModel.projects.first { $0.id == stack.projectID },
                            runningCount: manager.containers.filter { $0.isRunning && project(for: $0)?.id == stack.projectID }.count,
                            isBusy: manager.isBusy(stack),
                            canRun: manager.state == .running && !manager.isBusy(stack),
                            canEdit: !manager.isSaving,
                            run: { action in
                                if action == .down { stoppingStack = stack }
                                else { Task { await manager.perform(action, on: stack, projects: viewModel.projects) } }
                            },
                            edit: { manager.requestOpen(stack) })
                    }
                }
            }
        }
    }
}

// MARK: - Metric

private struct DockerMetric: View {
    let kind: DockerIcon.Kind
    let tint: Color
    let label: String
    let value: String?
    var footnote: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            DockerIconTile(kind: kind, tint: tint, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold)).textCase(.uppercase)
                    .foregroundStyle(Color.daTertiaryText).lineLimit(1)
                if let value {
                    Text(value)
                        .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Color.daPrimaryText)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                } else {
                    SkeletonBlock().frame(width: 52, height: 15).padding(.vertical, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .help(footnote ?? label)
    }
}

// MARK: - Container card

private struct DockerContainerCard: View {
    let container: DockerContainer
    let project: ProjectInfo?
    let isBusy: Bool
    let openProject: () -> Void
    let action: (DockerContainerAction) -> Void
    let logs: () -> Void
    let shell: () -> Void

    private var tint: Color { container.stateColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                leadingIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.name)
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        .textSelection(.enabled)
                    HStack(spacing: 4) {
                        DockerIcon(.image, size: 10).foregroundStyle(.tertiary)
                        Text(container.image)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    .help(container.image)
                }
                Spacer(minLength: 4)
                actions
            }

            HStack(spacing: 5) {
                DockerChip(text: container.stateTitle, tint: tint)
                if container.isRunning {
                    if let cpu = container.cpuPercent {
                        DockerChip(kind: .cpu, text: String(format: "%.1f%%", cpu), tint: .orange)
                    }
                    if let memory = container.memoryUsage {
                        DockerChip(kind: .memory, text: memory.components(separatedBy: " / ").first ?? memory, tint: .teal)
                            .help(memory)
                    }
                }
                Spacer(minLength: 4)
                owner
            }

            if !container.ports.isEmpty {
                FlowLayout(spacing: 5) {
                    ForEach(container.ports) { port in
                        Menu {
                            if let url = port.browserURL {
                                Link(destination: url) { Label("docker.openBrowser".localized, image: "docker-external") }
                            }
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(port.title, forType: .string)
                            } label: { Label("docker.copy".localized, image: "docker-copy") }
                        } label: {
                            DockerChip(kind: .port, text: port.title, tint: .daDocker, monospaced: true)
                        }
                        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                        .help(port.hostIP)
                    }
                }
            }
        }
        .dockerCard(tint: tint)
        .opacity(container.isRunning ? 1 : 0.92)
    }

    @ViewBuilder private var leadingIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            if let project {
                ProjectFolderIcon(project: project, size: 38, isInteractive: false)
            } else {
                DockerIconTile(kind: .forImage(container.image), tint: container.isRunning ? .daDocker : .secondary, size: 38)
            }
            DockerStatusDot(color: tint, isLive: container.isRunning, size: 9)
                .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                .offset(x: 2, y: 2)
                .accessibilityLabel(container.stateTitle)
        }
        .frame(width: 38, height: 38)
    }

    @ViewBuilder private var owner: some View {
        if let project {
            Button(action: openProject) {
                HStack(spacing: 4) {
                    DockerIcon(.folder, size: 10.5)
                    Text(project.name).lineLimit(1)
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.daAccent)
            }
            .buttonStyle(.plain)
            .help(project.path)
        } else if let stack = container.composeProject {
            HStack(spacing: 4) {
                DockerIcon(.stack, size: 10.5)
                Text(stack).lineLimit(1)
            }
            .font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            if isBusy {
                ProgressView().controlSize(.small).frame(width: 26, height: 26)
            } else if container.isRunning || container.state == "restarting" {
                DockerIconButton(kind: .stop, help: "docker.action.stop".localized, tint: .red) { action(.stop) }
            } else {
                DockerIconButton(kind: .play, help: "docker.action.start".localized, tint: .green) { action(.start) }
                    .disabled(!["created", "exited"].contains(container.state))
            }
            DockerIconButton(kind: .logs, help: "docker.logs".localized, action: logs)
            DockerIconButton(kind: .terminal, help: "docker.shell".localized, action: shell)
                .disabled(!container.isRunning || isBusy)
            Menu {
                Button { action(.restart) } label: { Label("docker.action.restart".localized, image: "docker-restart") }
                    .disabled(!["running", "restarting"].contains(container.state))
                Divider()
                Button(role: .destructive) { action(.remove) } label: { Label("docker.action.remove".localized, image: "docker-trash") }
                    .disabled(!["created", "exited", "dead"].contains(container.state))
            } label: {
                DockerIcon(.more, size: 12.5)
                    .foregroundStyle(Color.daSecondaryText)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .help("docker.actions".localized)
            .disabled(isBusy)
        }
    }
}

// MARK: - Stack card

private struct DockerStackCard: View {
    let stack: DockerComposeStack
    let project: ProjectInfo?
    let runningCount: Int
    let isBusy: Bool
    let canRun: Bool
    let canEdit: Bool
    let run: (DockerStackAction) -> Void
    let edit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Group {
                if let project { ProjectFolderIcon(project: project, size: 38, isInteractive: false) }
                else { DockerIconTile(kind: .stack, tint: .purple, size: 38) }
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(stack.projectName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                HStack(spacing: 5) {
                    HStack(spacing: 4) {
                        DockerIcon(.compose, size: 10).foregroundStyle(.tertiary)
                        Text(stack.fileURL.lastPathComponent)
                            .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .help(stack.fileURL.path)
                    if runningCount > 0 {
                        DockerChip(text: "docker.runningCount".localized(runningCount), tint: .green)
                    }
                }
            }
            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if isBusy { ProgressView().controlSize(.small).frame(width: 26, height: 26) }
                DockerIconButton(kind: .play, help: "docker.stack.up".localized, tint: .green) { run(.up) }
                    .disabled(!canRun)
                DockerIconButton(kind: .hammer, help: "docker.stack.rebuild".localized) { run(.rebuild) }
                    .disabled(!canRun)
                DockerIconButton(kind: .stop, help: "docker.stack.down".localized, tint: .red) { run(.down) }
                    .disabled(!canRun)
                DockerIconButton(kind: .pencil, help: "docker.stack.edit".localized, tint: .daDocker, action: edit)
                    .disabled(!canEdit)
            }
        }
        .dockerCard(tint: .purple)
    }
}
