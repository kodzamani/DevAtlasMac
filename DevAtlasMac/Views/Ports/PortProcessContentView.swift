import SwiftUI

struct PortProcessContentView: View {
    let viewModel: AppViewModel

    private var rows: [PortListener] {
        viewModel.projectPortListeners.filter { listener in
            let project = viewModel.project(for: listener)
            let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty || [String(listener.port), String(listener.pid), listener.command,
                                    listener.address, listener.workingDirectory ?? "", project?.name ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        // Keep this screen's ideal size from enlarging the split view and shifting its sidebar.
        GeometryReader { geometry in
            content
                .padding(28)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .task { await viewModel.portManager.refresh() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.5).padding(.top, 20)

            if rows.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let error = viewModel.portManager.errorMessage {
                    HStack(spacing: 8) {
                        PortIcon(.warning)
                        Text(error).textSelection(.enabled)
                    }
                    .font(.callout).foregroundStyle(.orange).padding(.top, 16)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 270, maximum: 380), spacing: 12, alignment: .top)],
                              spacing: 12) {
                        ForEach(rows) { listener in
                            PortGridCard(listener: listener, viewModel: viewModel)
                        }
                        RunNewProjectCard(viewModel: viewModel)
                    }
                    .padding(.vertical, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            PortIcon(.network, size: 22)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    LinearGradient(colors: [Color.daAccent, Color.daAccent.opacity(0.65)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: Color.daAccent.opacity(0.35), radius: 8, y: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text("tab.ports".localized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("ports.subtitle".localized)
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 7) {
                    Circle().fill(rows.isEmpty ? Color.secondary.opacity(0.5) : Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: rows.isEmpty ? .clear : .green.opacity(0.7), radius: 3)
                    Text("ports.count".localized(rows.count)).monospacedDigit()
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.primary.opacity(0.05), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.06)))
                if let date = viewModel.portManager.lastUpdated {
                    (Text("ports.updated".localized) + Text(date, style: .time))
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var hasQuery: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyState: some View {
        let error = viewModel.portManager.errorMessage
        let isLoading = viewModel.portManager.isScanning && viewModel.portManager.lastUpdated == nil
        let title = error != nil ? "ports.unavailable" : (isLoading ? "ports.scanning" : (hasQuery ? "ports.noResults" : "ports.empty"))
        let detail = error ?? (hasQuery ? "ports.noResults.detail".localized : "ports.empty.detail".localized)
        return VStack(spacing: 0) {
            PortIcon(error != nil ? .warning : (hasQuery ? .search : .network), size: 36)
                .foregroundStyle(error != nil ? Color.orange : Color.daAccent)
                .frame(width: 88, height: 88)
                .background(Color.daAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 26))
                .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.daAccent.opacity(0.12)))
                .padding(.bottom, 24)

            Text(title.localized)
                .font(.system(size: 19, weight: .semibold))
                .padding(.bottom, 10)
            Text(detail)
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .lineSpacing(5).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 350)
                .padding(.bottom, 24)

            if isLoading {
                ProgressView().controlSize(.small)
            } else if !hasQuery && error == nil {
                RunNewProjectCard(viewModel: viewModel).frame(maxWidth: 300)
            } else {
                Button {
                    if hasQuery { viewModel.searchText = "" }
                    else { Task { await viewModel.portManager.refresh() } }
                } label: {
                    HStack(spacing: 7) {
                        PortIcon(hasQuery ? .search : .refresh, size: 14)
                        Text((hasQuery ? "ports.clearSearch" : "ports.refresh").localized)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.portManager.isScanning)
            }
        }
        .padding(32)
        .frame(maxWidth: 460)
    }
}

/// Last grid card: lists web projects (package.json with a start script) that aren't running yet.
struct RunNewProjectCard: View {
    let viewModel: AppViewModel
    @State private var isPresented = false
    @State private var candidates: [ProjectInfo] = []
    @State private var isHovering = false

    private func loadCandidates() {
        let running = Set(viewModel.projectPortListeners.compactMap { viewModel.project(for: $0)?.id })
        candidates = viewModel.projects.filter {
            $0.projectType != "React Native" && !running.contains($0.id)
                && viewModel.runner.isRunnableProject(at: $0.path)
        }.sorted { $0.lastModified > $1.lastModified }
    }

    var body: some View {
        Button {
            loadCandidates()
            isPresented = true
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.daAccent)
                    .frame(width: 46, height: 46)
                    .background(Color.daAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ports.runNew".localized).font(.system(size: 13, weight: .semibold))
                    Text("ports.runNew.detail".localized)
                        .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.daAccent.opacity(isHovering ? 0.06 : 0.025), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.daAccent.opacity(isHovering ? 0.6 : 0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ports.runNew.title".localized)
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                if candidates.isEmpty {
                    Text("ports.runNew.empty".localized)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .padding(14).frame(width: 300, alignment: .leading)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(candidates) { project in
                                Button {
                                    isPresented = false
                                    viewModel.runProject(project)
                                    Task {
                                        try? await Task.sleep(for: .seconds(4))
                                        await viewModel.portManager.refresh()
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        ProjectFolderIcon(project: project, size: 34, isInteractive: false)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(project.name).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                                            Text(project.projectType).font(.system(size: 10.5)).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "play.circle.fill").foregroundStyle(Color.daAccent)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 6).padding(.bottom, 8)
                    }
                    .frame(width: 300, height: min(CGFloat(candidates.count) * 46 + 12, 320))
                }
            }
        }
    }
}

/// Original vector assets shared by the port screen, chat cards and toolbar.
struct PortIcon: View {
    enum Kind: String { case network, refresh, external, stop, warning, search }
    let kind: Kind
    let size: CGFloat

    init(_ kind: Kind, size: CGFloat = 18) {
        self.kind = kind
        self.size = size
    }

    var body: some View {
        Image("port-" + kind.rawValue)
            .renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Compact grid card: project icon + name lead, port badge and actions sit alongside.
struct PortGridCard: View {
    let listener: PortListener
    let viewModel: AppViewModel
    @State private var isHovering = false

    private var project: ProjectInfo? { viewModel.project(for: listener) }
    private var tint: Color { project.map { Color(hex: $0.displayIconColor) } ?? Color.daAccent }
    private var isStopping: Bool { viewModel.portManager.stoppingPIDs.contains(listener.pid) }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Group {
                if let project {
                    ProjectFolderIcon(project: project, size: 46, isInteractive: false)
                } else {
                    PortIcon(.network, size: 20).foregroundStyle(tint)
                        .frame(width: 46, height: 46)
                        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                if let project {
                    Button { viewModel.openProject(project) } label: {
                        Text(project.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    }
                    .buttonStyle(.plain).help(project.path)
                } else {
                    Text(listener.command).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(":" + String(listener.port))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(tint.opacity(0.12), in: Capsule())
                    Text(project == nil ? "PID \(listener.pid)" : "\(listener.command) · \(listener.pid)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if let url = listener.browserURL {
                    Link(destination: url) {
                        PortIcon(.external, size: 13).frame(width: 26, height: 26)
                            .background(.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("ports.openBrowser".localized)
                    .accessibilityLabel("ports.openBrowser".localized)
                }
                Button {
                    Task { await viewModel.portManager.stop(listener) }
                } label: {
                    PortIcon(.stop, size: 13).foregroundStyle(.red)
                        .frame(width: 26, height: 26)
                        .background(Color.red.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(listener.startedAt == nil || isStopping)
                .help("ports.stop.help".localized)
                .accessibilityLabel("ports.stop".localized)
            }
        }
        .padding(11)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(isHovering ? tint.opacity(0.45) : Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(isHovering ? 0.12 : 0.04), radius: isHovering ? 8 : 3, y: 2)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .help(listener.workingDirectory ?? "ports.unknownDirectory".localized)
    }
}

/// Chat keeps a dated snapshot; actions revalidate the process before sending SIGTERM.
struct ChatPortsCard: View {
    let listeners: [PortListener]
    let viewModel: AppViewModel

    private var projectListeners: [PortListener] {
        listeners.filter { viewModel.project(for: $0) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PortIcon(.network)
                Text("tab.ports".localized)
            }.font(.headline)
            if projectListeners.isEmpty {
                Text("ports.empty".localized).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 8, alignment: .top)], spacing: 8) {
                ForEach(projectListeners) { listener in
                    PortGridCard(listener: listener, viewModel: viewModel)
                }
            }
            if let error = viewModel.portManager.errorMessage {
                Text(error).foregroundStyle(.orange)
            }
            Button("ports.showAll".localized) { viewModel.selectedTab = .ports }
        }
    }
}
