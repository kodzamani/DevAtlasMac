import SwiftUI

/// Picks an agent (and, when no project is fixed, a project) and starts a session.
/// Used by the Agents tab, its "+" button and the project page.
struct AgentLaunchPopover: View {
    let manager: AgentSessionsViewModel
    let projects: [ProjectInfo]
    /// Set from the project page: the session opens in this project and the picker is hidden.
    var fixedProject: ProjectInfo?
    let onLaunch: (AgentSession) -> Void

    @State private var selectedProjectID: String?
    @State private var prompt = ""

    private var project: ProjectInfo? {
        fixedProject ?? projects.first { $0.id == selectedProjectID } ?? projects.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("agents.openWithAgent".localized)
                .font(.daBodySemiBold)
                .foregroundStyle(Color.daPrimaryText)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                if fixedProject == nil {
                    AgentProjectPicker(projects: projects, selection: $selectedProjectID)
                }
                TextField("agents.prompt.placeholder".localized, text: $prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .font(.daBody)
            }
            .padding(.horizontal, 16).padding(.bottom, 10)

            Divider()

            AgentList(manager: manager, isEnabled: project != nil) { agent in
                guard let project,
                      let session = manager.start(agent, projectName: project.name, directory: project.path, prompt: prompt) else { return }
                onLaunch(session)
            } onShell: {
                guard let project else { return }
                onLaunch(manager.startShell(projectName: project.name, directory: project.path))
            }
            .padding(.vertical, 4)
        }
        .frame(width: 290)
        .task { await manager.ensureDetected() }
        .onAppear { if selectedProjectID == nil { selectedProjectID = projects.first?.id } }
    }
}

struct AgentProjectPicker: View {
    let projects: [ProjectInfo]
    @Binding var selection: String?

    var body: some View {
        Picker("agents.project".localized, selection: $selection) {
            if projects.isEmpty {
                Text("agents.selectProject".localized).tag(String?.none)
            }
            ForEach(projects) { project in
                Text(project.name).tag(Optional(project.id))
            }
        }
        .pickerStyle(.menu)
        .font(.daBody)
    }
}

/// Installed agents as rows, then a plain shell, then the ones that were not found.
struct AgentList: View {
    let manager: AgentSessionsViewModel
    let isEnabled: Bool
    let onAgent: (DetectedAgent) -> Void
    let onShell: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if manager.isDetecting && !manager.hasDetected {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("agents.detecting".localized).font(.daBody).foregroundStyle(Color.daMutedText)
                }
                .padding(16)
            } else {
                if manager.installedAgents.isEmpty {
                    Text("agents.none.detail".localized)
                        .font(.daBody).foregroundStyle(Color.daMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                }
                // The last agent used comes first.
                ForEach(manager.installedAgents.sorted { $0.id == manager.preferredAgentID && $1.id != manager.preferredAgentID }) { agent in
                    AgentPickerRow(agent: agent) { onAgent(agent) }
                        .disabled(!isEnabled)
                }
                AgentShellRow(action: onShell).disabled(!isEnabled)
            }
        }
    }
}

struct AgentPickerRow: View {
    let agent: DetectedAgent
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AgentMonogram(agent: agent.agent, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.agent.name)
                        .font(.daBody)
                        .foregroundStyle(Color.daPrimaryText)
                    if let version = agent.version {
                        Text(version).font(.daSmallLabel).foregroundStyle(Color.daMutedText)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(isHovered ? Color.daLightGray : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(agent.path ?? "")
    }
}

private struct AgentShellRow: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                LineGlyphView(glyph: .terminal)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("agents.openShell".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daSecondaryText)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(isHovered ? Color.daLightGray : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// A neutral two-letter tile; the agents' own logos are not bundled.
struct AgentMonogram: View {
    let agent: CodingAgent
    var size: CGFloat = 24
    var dimmed = false

    private var letters: String {
        let words = agent.name.split(separator: " ")
        if words.count > 1 { return String(words.prefix(2).compactMap(\.first)) }
        return String(agent.name.prefix(2))
    }

    private var tint: Color {
        let palette: [Color] = [.orange, .blue, .purple, .teal, .green, .pink, .indigo, .mint, .brown, .cyan]
        let seed = agent.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[seed % palette.count]
    }

    var body: some View {
        Text(letters)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(dimmed ? Color.daMutedText : tint)
            .frame(width: size, height: size)
            .background((dimmed ? Color.primary : tint).opacity(dimmed ? 0.05 : 0.15),
                        in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}
