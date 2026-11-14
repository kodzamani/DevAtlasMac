import SwiftUI

struct DockerComposeEditorView: View {
    let viewModel: AppViewModel
    private var manager: DockerViewModel { viewModel.dockerManager }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if manager.activeStack == nil {
                emptyState
            } else {
                topBar
                editor
                    .disabled(manager.isSaving)
                    .frame(maxHeight: .infinity)
                if let error = manager.visualError {
                    DockerBanner(kind: .warning, tint: .red, text: error)
                }
                if let message = manager.validationMessage {
                    DockerBanner(kind: manager.validationSucceeded ? .check : .warning,
                                 tint: manager.validationSucceeded ? .green : .red,
                                 text: message, monospaced: !manager.validationSucceeded)
                }
                actionBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog("docker.unsaved.title".localized, isPresented: Binding(get: { manager.pendingStack != nil }, set: { if !$0 { manager.pendingStack = nil } }), titleVisibility: .visible) {
            Button("docker.discard".localized, role: .destructive) { if let stack = manager.pendingStack { manager.open(stack) } }
            Button("docker.cancel".localized, role: .cancel) { manager.pendingStack = nil }
        } message: { Text("docker.unsaved.detail".localized) }
        .task {
            while !Task.isCancelled {
                await viewModel.portManager.refresh()
                do { try await Task.sleep(for: .seconds(8)) } catch { break }
            }
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        @Bindable var manager = manager
        return HStack(spacing: 11) {
            DockerIconTile(kind: .compose, tint: .daDocker, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(manager.activeStack?.projectName ?? "").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    if manager.isDirty {
                        DockerChip(text: "docker.unsaved".localized, tint: .orange)
                    }
                }
                if let stack = manager.activeStack {
                    Text(stack.fileURL.path)
                        .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                        .help(stack.fileURL.path)
                }
            }
            Spacer(minLength: 8)
            fileMenu(prominent: false).disabled(manager.isSaving)
            modeSwitch(isYAML: $manager.isYAMLMode).disabled(manager.isSaving)
        }
    }

    private func modeSwitch(isYAML: Binding<Bool>) -> some View {
        HStack(spacing: 2) {
            ForEach([false, true], id: \.self) { yaml in
                let isOn = isYAML.wrappedValue == yaml
                Button { isYAML.wrappedValue = yaml } label: {
                    HStack(spacing: 5) {
                        DockerIcon(yaml ? .compose : .sliders, size: 11.5)
                        Text((yaml ? "docker.yaml" : "docker.visual").localized).lineLimit(1)
                    }
                    .font(.system(size: 11.5, weight: isOn ? .semibold : .medium))
                    .foregroundStyle(isOn ? Color.daPrimaryText : Color.daTertiaryText)
                    .padding(.horizontal, 10).frame(height: 24)
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
        .accessibilityLabel("docker.editorMode".localized)
    }

    private func fileMenu(prominent: Bool) -> some View {
        Menu {
            ForEach(manager.stacks) { stack in
                Button { manager.requestOpen(stack) } label: {
                    Label("\(stack.projectName) · \(stack.fileURL.lastPathComponent)", image: "docker-compose")
                }
            }
            Divider()
            Menu {
                ForEach(viewModel.projects.filter { project in !manager.stacks.contains { $0.projectID == project.id } }) { project in
                    Button(project.name) {
                        manager.requestOpen(.init(projectID: project.id, projectName: project.name, fileURL: URL(fileURLWithPath: project.path).appendingPathComponent("compose.yaml")))
                    }
                }
            } label: { Label("docker.newCompose".localized, image: "docker-plus") }
            .disabled(viewModel.projects.isEmpty)
        } label: {
            DockerActionLabel(kind: .folder, title: "docker.openCompose".localized, style: prominent ? .prominent : .plain)
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            DockerIcon(.compose, size: 34)
                .foregroundStyle(Color.daDocker)
                .frame(width: 80, height: 80)
                .background(Color.daDocker.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.daDocker.opacity(0.14)))
                .padding(.bottom, 20)
            Text("docker.studio.empty".localized).font(.system(size: 17, weight: .semibold)).padding(.bottom, 8)
            Text("docker.studio.detail".localized)
                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 340).padding(.bottom, 20)
            fileMenu(prominent: true)
            HStack(spacing: 14) {
                ForEach([DockerServiceTemplate.postgres, .redis, .rabbitmq, .minio, .mailpit], id: \.self) { template in
                    VStack(spacing: 5) {
                        DockerIconTile(kind: template.icon, tint: .secondary, size: 30)
                        Text(template.title).font(.system(size: 9.5)).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.top, 28)
            .accessibilityHidden(true)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            DockerActionButton(kind: .revert, title: "docker.revert".localized) { manager.revert() }
                .disabled(!manager.isDirty || manager.isSaving)
            Spacer(minLength: 8)
            if manager.isSaving { ProgressView().controlSize(.small) }
            DockerActionButton(kind: .check, title: "docker.validate".localized) { Task { await manager.validate() } }
                .disabled(manager.isSaving || manager.visualError != nil)
            DockerActionButton(kind: .save, title: "docker.save".localized) { Task { await manager.save(apply: false, projects: viewModel.projects) } }
                .disabled(!manager.isDirty || manager.isSaving || manager.visualError != nil)
            DockerActionButton(kind: .deploy, title: "docker.saveApply".localized, style: .prominent) {
                Task { await manager.save(apply: true, projects: viewModel.projects) }
            }
            .disabled(manager.state != .running || manager.isSaving || manager.visualError != nil || manager.activeStack.map { manager.isBusy($0) } == true)
        }
    }

    // MARK: Editor

    @ViewBuilder private var editor: some View {
        if manager.isYAMLMode {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    DockerIcon(.compose, size: 12).foregroundStyle(Color.daDocker)
                    Text(manager.activeStack?.fileURL.lastPathComponent ?? "compose.yaml")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    Spacer()
                    Text("YAML").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12).frame(height: 30)
                Divider().opacity(0.6)
                TextEditor(text: Binding(get: { manager.yaml }, set: { manager.setYAML($0) }))
                    .font(.system(size: 12, design: .monospaced)).autocorrectionDisabled()
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8).padding(.vertical, 6)
            }
            .daCardSurface()
        } else if manager.document?.visualUnavailable == true {
            VStack(spacing: 14) {
                DockerIconTile(kind: .warning, tint: .orange, size: 44)
                Text("docker.error.visualUnavailable".localized)
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 360)
                DockerActionButton(kind: .compose, title: "docker.switchYAML".localized, style: .prominent) { manager.isYAMLMode = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(24).daCardSurface()
        } else {
            HStack(spacing: 0) {
                serviceList.frame(width: 210)
                Divider().opacity(0.6)
                if let service = manager.selectedService {
                    DockerComposeServiceForm(
                        service: Binding(get: { manager.document?.services.first { $0.id == service.id } ?? service }, set: { manager.updateService($0) }),
                        otherServices: manager.document?.services.filter { $0.id != service.id }.map(\.name) ?? [],
                        listeners: viewModel.portManager.listeners,
                        hasEnvFile: manager.activeStack.map { FileManager.default.fileExists(atPath: $0.fileURL.deletingLastPathComponent().appendingPathComponent(".env").path) } ?? false,
                        isExisting: manager.document?.originalServices.contains { $0.id == service.id } == true)
                    .id(service.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        DockerIconTile(kind: .plus, tint: .daDocker, size: 40)
                        Text("docker.addService.detail".localized).font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .daCardSurface()
        }
    }

    private var serviceList: some View {
        let services = manager.document?.services ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("docker.services".localized)
                    .font(.system(size: 10, weight: .semibold)).textCase(.uppercase)
                    .foregroundStyle(Color.daTertiaryText)
                Text("\(services.count)")
                    .font(.system(size: 10, weight: .semibold)).monospacedDigit().foregroundStyle(.tertiary)
                Spacer()
                Menu {
                    ForEach(DockerServiceTemplate.allCases) { template in
                        Button { manager.addService(template) } label: { Label(template.title, image: "docker-" + template.icon.rawValue) }
                    }
                } label: {
                    DockerIcon(.plus, size: 11)
                        .foregroundStyle(Color.daDocker)
                        .frame(width: 22, height: 22)
                        .background(Color.daDocker.opacity(0.12), in: Circle())
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .help("docker.addService".localized)
            }
            .padding(.horizontal, 12).frame(height: 38)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(services) { service in
                        DockerServiceRow(service: service, isSelected: manager.selectedServiceID == service.id) {
                            manager.selectedServiceID = service.id
                        }
                    }
                }
                .padding(.horizontal, 6).padding(.bottom, 8)
            }
        }
    }
}

private struct DockerServiceRow: View {
    let service: DockerComposeService
    let isSelected: Bool
    let select: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 9) {
                DockerIconTile(kind: .forImage(service.image, isBuild: service.useBuild),
                               tint: isSelected ? .daDocker : .secondary, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(service.name)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium)).lineLimit(1)
                    Text(service.useBuild ? service.buildContext : (service.image.isEmpty ? "—" : service.image))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 0)
                if !service.ports.isEmpty {
                    HStack(spacing: 2) {
                        DockerIcon(.port, size: 9)
                        Text("\(service.ports.count)").font(.system(size: 9.5, weight: .semibold)).monospacedDigit()
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .background(isSelected ? Color.daDocker.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : .clear),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Service form

private struct DockerComposeServiceForm: View {
    @Binding var service: DockerComposeService
    let otherServices: [String]
    let listeners: [PortListener]
    let hasEnvFile: Bool
    let isExisting: Bool
    @State private var revealSecrets = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !service.lockedFields.isEmpty {
                    DockerBanner(kind: .lock, tint: .orange,
                                 text: "docker.advancedFields".localized(service.lockedFields.sorted().joined(separator: ", ")))
                }
                basics
                ports
                environment
                volumes
                envFiles
                dependencies
                networks
            }
            .padding(14)
        }
    }

    // Basic settings

    private var basics: some View {
        DockerFormSection(kind: .sliders, tint: .daDocker, title: "docker.basic".localized) {
            DockerFieldRow(label: "docker.field.name".localized) {
                HStack(spacing: 6) {
                    TextField("docker.serviceName".localized, text: $service.name).dockerField(monospaced: true)
                        .disabled(isExisting)
                    if isExisting {
                        DockerIcon(.lock, size: 12).foregroundStyle(.tertiary).help("docker.renameHint".localized)
                    }
                }
            }
            DockerFieldRow(label: "docker.field.source".localized) {
                Picker("docker.field.source".localized, selection: $service.useBuild) {
                    Text("docker.source.image".localized).tag(false)
                    Text("docker.source.build".localized).tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .disabled(locked("build") || locked("image"))
            }
            if service.useBuild {
                DockerFieldRow(label: "docker.field.context".localized) {
                    HStack(spacing: 6) {
                        TextField("docker.buildContext".localized, text: $service.buildContext).dockerField(monospaced: true)
                        DockerIcon(.compose, size: 12).foregroundStyle(.tertiary)
                        TextField("docker.dockerfile".localized, text: $service.dockerfile).dockerField(monospaced: true)
                    }
                    .disabled(locked("build"))
                }
            } else {
                DockerFieldRow(label: "docker.field.image".localized) {
                    TextField("docker.image".localized, text: $service.image).dockerField(monospaced: true)
                        .disabled(locked("image"))
                }
            }
            DockerFieldRow(label: "docker.field.container".localized) {
                TextField("docker.field.optional".localized, text: $service.containerName).dockerField(monospaced: true)
                    .disabled(locked("container_name"))
            }
            DockerFieldRow(label: "docker.field.restart".localized) {
                Picker("docker.restartPolicy".localized, selection: $service.restart) {
                    Text("docker.default".localized).tag("")
                    // Keep nonstandard values visible; Compose also accepts on-failure:N.
                    if !["", "no", "always", "unless-stopped", "on-failure"].contains(service.restart) { Text(service.restart).tag(service.restart) }
                    ForEach(["no", "always", "unless-stopped", "on-failure"], id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().fixedSize()
                .disabled(locked("restart"))
            }
            DockerFieldRow(label: "docker.field.command".localized) {
                TextField("docker.field.optional".localized, text: $service.command).dockerField(monospaced: true)
                    .disabled(locked("command"))
            }
            DockerFieldRow(label: "docker.field.workdir".localized) {
                TextField("docker.field.optional".localized, text: $service.workingDirectory).dockerField(monospaced: true)
                    .disabled(locked("working_dir"))
            }
        }
    }

    // Ports

    private var ports: some View {
        DockerFormSection(kind: .port, tint: .green, title: "docker.ports".localized, count: service.ports.count) {
            DockerIconButton(kind: .plus, help: "docker.addPort".localized, tint: .green, size: 22) { service.ports.append(.init()) }
        } content: {
            if service.ports.isEmpty {
                emptyLine("docker.ports.empty")
            } else {
                HStack(spacing: 6) {
                    columnLabel("docker.hostIP", width: 104)
                    columnLabel("docker.hostPort", width: 74)
                    Spacer().frame(width: 14)
                    columnLabel("docker.targetPort", width: 74)
                    columnLabel("docker.protocol", width: nil)
                }
                ForEach($service.ports) { $port in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            TextField("0.0.0.0", text: $port.hostIP).dockerField(monospaced: true).frame(width: 104)
                            TextField("8080", text: $port.host).dockerField(monospaced: true).frame(width: 74)
                            DockerIcon(.arrow, size: 12).foregroundStyle(.tertiary).frame(width: 14)
                            TextField("80", text: $port.target).dockerField(monospaced: true).frame(width: 74)
                            Picker("docker.protocol".localized, selection: $port.transport) {
                                Text("tcp").tag("tcp"); Text("udp").tag("udp")
                            }
                            .pickerStyle(.segmented).labelsHidden().fixedSize()
                            Spacer(minLength: 0)
                            removeButton { service.ports.removeAll { $0.id == port.id } }
                        }
                        if port.transport == "tcp", let host = Int(port.host), listeners.contains(where: { $0.port == host }) {
                            HStack(spacing: 5) {
                                DockerIcon(.warning, size: 11)
                                Text("docker.portConflict".localized(port.host))
                            }
                            .font(.system(size: 11)).foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .disabled(locked("ports"))
    }

    // Environment

    private var environment: some View {
        DockerFormSection(kind: .key, tint: .orange, title: "docker.environment".localized, count: service.environment.count) {
            DockerIconButton(kind: .eye, help: "docker.revealSecrets".localized, tint: revealSecrets ? .orange : nil, size: 22) {
                revealSecrets.toggle()
            }
            DockerIconButton(kind: .plus, help: "docker.addVariable".localized, tint: .orange, size: 22) { service.environment.append(.init()) }
        } content: {
            if service.environment.isEmpty {
                emptyLine("docker.env.empty")
            }
            ForEach($service.environment) { $variable in
                HStack(spacing: 6) {
                    TextField("KEY", text: $variable.key).dockerField(monospaced: true).frame(width: 170)
                    Text("=").font(.system(size: 12, design: .monospaced)).foregroundStyle(.tertiary)
                    Group {
                        if variable.isSecret && !revealSecrets {
                            SecureField("VALUE", text: Binding(get: { variable.value ?? "" }, set: { variable.value = $0 }))
                        } else {
                            TextField("VALUE", text: Binding(get: { variable.value ?? "" }, set: { variable.value = $0 }))
                        }
                    }
                    .dockerField(monospaced: true)
                    .disabled(variable.value == nil)
                    if variable.isSecret {
                        DockerIcon(.lock, size: 11).foregroundStyle(.orange).help("docker.revealSecrets".localized)
                    }
                    Toggle("docker.inherit".localized, isOn: Binding(get: { variable.value == nil }, set: { variable.value = $0 ? nil : "" }))
                        .toggleStyle(.checkbox).font(.system(size: 11)).fixedSize()
                    removeButton { service.environment.removeAll { $0.id == variable.id } }
                }
            }
        }
        .disabled(locked("environment"))
    }

    // Volumes

    private var volumes: some View {
        DockerFormSection(kind: .volume, tint: .purple, title: "docker.volumes".localized, count: service.volumes.count) {
            DockerIconButton(kind: .plus, help: "docker.addVolume".localized, tint: .purple, size: 22) { service.volumes.append(.init()) }
        } content: {
            if service.volumes.isEmpty {
                emptyLine("docker.volumes.empty")
            }
            ForEach($service.volumes) { $mount in
                HStack(spacing: 6) {
                    TextField("docker.volumeSource".localized, text: $mount.source).dockerField(monospaced: true)
                    DockerIcon(.arrow, size: 12).foregroundStyle(.tertiary)
                    TextField("docker.volumeTarget".localized, text: $mount.target).dockerField(monospaced: true)
                    Button { mount.readOnly.toggle() } label: {
                        DockerChip(kind: .lock, text: "ro", tint: mount.readOnly ? .purple : .secondary, monospaced: true)
                            .opacity(mount.readOnly ? 1 : 0.6)
                    }
                    .buttonStyle(.plain)
                    .help("docker.readOnly".localized)
                    removeButton { service.volumes.removeAll { $0.id == mount.id } }
                }
            }
        }
        .disabled(locked("volumes"))
    }

    // Env files, dependencies, networks

    private var envFiles: some View {
        DockerFormSection(kind: .envfile, tint: .teal, title: "docker.envFiles".localized) {
            HStack(spacing: 8) {
                Toggle("docker.linkEnv".localized, isOn: Binding(get: { service.envFiles.contains(".env") }, set: { enabled in
                    service.envFiles.removeAll { $0 == ".env" }; if enabled { service.envFiles.append(".env") }
                }))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                .disabled(locked("env_file") || (!hasEnvFile && !service.envFiles.contains(".env")))
                Spacer(minLength: 4)
                ForEach(service.envFiles, id: \.self) { DockerChip(kind: .envfile, text: $0, tint: .teal, monospaced: true) }
            }
            if !hasEnvFile {
                emptyLine("docker.envMissing")
            }
        }
    }

    private var dependencies: some View {
        DockerFormSection(kind: .link, tint: .pink, title: "docker.dependencies".localized, count: service.dependencies.count) {
            if otherServices.isEmpty {
                emptyLine("docker.deps.empty")
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(otherServices, id: \.self) { name in
                        let isOn = service.dependencies.contains(name)
                        Button {
                            service.dependencies.removeAll { $0 == name }
                            if !isOn { service.dependencies.append(name) }
                        } label: {
                            HStack(spacing: 5) {
                                DockerIcon(isOn ? .check : .plus, size: 11)
                                Text(name).font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            }
                            .foregroundStyle(isOn ? Color.pink : Color.daSecondaryText)
                            .padding(.horizontal, 9).frame(height: 24)
                            .background((isOn ? Color.pink : Color.primary).opacity(isOn ? 0.12 : 0.05), in: Capsule())
                            .overlay(Capsule().strokeBorder(isOn ? Color.pink.opacity(0.3) : Color.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .disabled(locked("depends_on"))
    }

    private var networks: some View {
        DockerFormSection(kind: .network, tint: .indigo, title: "docker.networks".localized, count: service.networks.count) {
            TextField("docker.networkNames".localized, text: Binding(get: { service.networks.joined(separator: ", ") }, set: { value in
                service.networks = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }))
            .dockerField(monospaced: true)
            emptyLine("docker.networkHint")
        }
        .disabled(locked("networks"))
    }

    // Helpers

    private func locked(_ field: String) -> Bool { service.lockedFields.contains(field) }

    private func emptyLine(_ key: String) -> some View {
        Text(key.localized).font(.system(size: 11)).foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func columnLabel(_ key: String, width: CGFloat?) -> some View {
        Text(key.localized)
            .font(.system(size: 9.5, weight: .semibold)).textCase(.uppercase)
            .foregroundStyle(.tertiary).lineLimit(1)
            .frame(width: width, alignment: .leading)
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        DockerIconButton(kind: .trash, help: "docker.action.remove".localized, tint: .red, size: 22, action: action)
    }
}

/// A titled block in the service form.
private struct DockerFormSection<Trailing: View, Content: View>: View {
    let kind: DockerIcon.Kind
    let tint: Color
    let title: String
    var count: Int? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                DockerIconTile(kind: kind, tint: tint, size: 24)
                Text(title).font(.system(size: 12.5, weight: .semibold))
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6).frame(height: 17)
                        .background(tint.opacity(0.12), in: Capsule())
                }
                Spacer(minLength: 4)
                trailing()
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
    }
}

extension DockerFormSection where Trailing == EmptyView {
    init(kind: DockerIcon.Kind, tint: Color, title: String, count: Int? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(kind: kind, tint: tint, title: title, count: count, trailing: { EmptyView() }, content: content)
    }
}

/// Label column + control, so filled fields stay understandable once placeholders disappear.
private struct DockerFieldRow<Field: View>: View {
    let label: String
    @ViewBuilder var field: () -> Field

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: 96, alignment: .leading)
            field()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
