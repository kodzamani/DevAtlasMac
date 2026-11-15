import SwiftUI

/// The Agents tab before any session is open, laid out like a new chat:
/// a mark and greeting in the middle, agents as starter cards, and a composer at the bottom.
struct AgentsEmptyStateView: View {
    let viewModel: AppViewModel

    @State private var selectedProjectID: String?
    @State private var prompt = ""
    @State private var hasAppeared = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var manager: AgentSessionsViewModel { viewModel.agentManager }

    /// Most recently touched first, which is usually the project the user means.
    private var projects: [ProjectInfo] {
        viewModel.projects.sorted { $0.lastModified > $1.lastModified }
    }

    private var selectedProject: ProjectInfo? {
        projects.first { $0.id == selectedProjectID } ?? projects.first
    }

    /// The agent the send button starts: the last one used, else the first installed.
    private var composerAgent: DetectedAgent? {
        manager.installedAgents.first { $0.id == manager.preferredAgentID } ?? manager.installedAgents.first
    }

    private var unavailableAgents: [DetectedAgent] { manager.agents.filter { !$0.isInstalled } }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    mark
                        .padding(.bottom, 20)
                        .modifier(AgentEntryStagger(isVisible: hasAppeared, index: 0))

                    Text(selectedProject.map { "agents.empty.titleProject".localized($0.name) } ?? "agents.empty.title".localized)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.daPrimaryText)
                        .multilineTextAlignment(.center)
                        .modifier(AgentEntryStagger(isVisible: hasAppeared, index: 1))

                    Text("agents.subtitle".localized)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.daTertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .modifier(AgentEntryStagger(isVisible: hasAppeared, index: 2))

                    agentsGrid
                        .padding(.top, 28)
                }
                .frame(maxWidth: ChatMetrics.columnWidth)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
                .frame(maxWidth: ChatMetrics.columnWidth)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
        }
        .onAppear {
            hasAppeared = true
            if selectedProjectID == nil {
                selectedProjectID = (viewModel.selectedProject ?? viewModel.highlightedProject ?? projects.first)?.id
            }
            // The field only takes focus once it is in a window.
            DispatchQueue.main.async { isFocused = true }
        }
    }

    // MARK: Middle

    private var mark: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.daAccent.opacity(0.22), Color.daAccent.opacity(0.06)],
                                     center: .center, startRadius: 2, endRadius: 40))
            Circle()
                .strokeBorder(Color.daAccent.opacity(0.28), lineWidth: 1)
            LineGlyphView(glyph: .terminal, isSelected: true)
                .scaleEffect(1.75)
        }
        .frame(width: 68, height: 68)
        .shadow(color: Color.daAccent.opacity(0.18), radius: 16, y: 4)
    }

    @ViewBuilder
    private var agentsGrid: some View {
        if manager.isDetecting && !manager.hasDetected {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("agents.detecting".localized).font(.daBody).foregroundStyle(Color.daMutedText)
            }
        } else if manager.installedAgents.isEmpty {
            VStack(spacing: 4) {
                Text("agents.none.title".localized).font(.daSectionHeaderSemiBold)
                Text("agents.none.detail".localized).font(.daBody).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 18) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(manager.installedAgents.enumerated()), id: \.element.id) { index, agent in
                        AgentStarterCard(agent: agent, isEnabled: selectedProject != nil) { launch(agent) }
                            .modifier(AgentEntryStagger(isVisible: hasAppeared, index: index + 3))
                    }
                }
                if !unavailableAgents.isEmpty {
                    Text("agents.notInstalled".localized + ": " + unavailableAgents.map(\.agent.name).joined(separator: ", "))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.daMutedText)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        let shape = RoundedRectangle(cornerRadius: ChatMetrics.composerCorner, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            TextField("agents.prompt.placeholder".localized, text: $prompt, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isFocused)
                .padding(.horizontal, 2)
                .frame(minHeight: 20)
                .onSubmit { if let agent = composerAgent { launch(agent) } }

            HStack(spacing: 6) {
                projectMenu
                shellButton
                Spacer(minLength: 8)
                agentMenu
                sendButton
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(shape)
        .onTapGesture { isFocused = true }
        .chatGlass(cornerRadius: ChatMetrics.composerCorner)
        .overlay(shape.strokeBorder(Color.daAccent.opacity(isFocused ? (colorScheme == .dark ? 0.22 : 0.30) : 0), lineWidth: 0.75)
            .allowsHitTesting(false))
        .animation(.easeOut(duration: 0.12), value: isFocused)
    }

    private var projectMenu: some View {
        Menu {
            Picker("agents.project".localized, selection: $selectedProjectID) {
                ForEach(projects) { Text($0.name).tag(Optional($0.id)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            AgentComposerChip(icon: .folder, title: selectedProject?.name ?? "agents.selectProject".localized)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(selectedProject?.path ?? "")
    }

    private var shellButton: some View {
        Button {
            guard let project = selectedProject else { return }
            manager.startShell(projectName: project.name, directory: project.path)
        } label: {
            ChatIcon(.terminal, size: 14.5)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(AgentHoverCircle())
        .disabled(selectedProject == nil)
        .help("agents.openShell".localized)
    }

    private var agentMenu: some View {
        Menu {
            Picker("agents.composer.agent".localized, selection: Binding(
                get: { composerAgent?.id },
                set: { manager.preferredAgentID = $0; isFocused = true }
            )) {
                ForEach(manager.installedAgents) { Text($0.agent.name).tag(Optional($0.id)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                if let agent = composerAgent {
                    AgentMonogram(agent: agent.agent, size: 18)
                }
                Text(composerAgent?.agent.name ?? "agents.none.title".localized)
                    .font(.system(size: 12, weight: .medium))
                ChatIcon(.chevronDown, size: 9)
                    .foregroundStyle(Color.daMutedText)
            }
            .foregroundStyle(Color.daSecondaryText)
            .padding(.leading, 4).padding(.trailing, 8)
            .frame(height: 28)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(manager.installedAgents.isEmpty)
    }

    private var sendButton: some View {
        let isEnabled = composerAgent != nil && selectedProject != nil
        return Button {
            if let agent = composerAgent { launch(agent) }
        } label: {
            ChatIcon(.arrowUp, size: 16, weight: 2)
                .foregroundStyle(isEnabled ? Color.white : Color.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isEnabled ? Color.daAccent : Color.primary.opacity(0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(AgentPressableStyle())
        .disabled(!isEnabled)
        .help(composerAgent.map { "agents.start".localized($0.agent.name) } ?? "")
    }

    private func launch(_ agent: DetectedAgent) {
        guard let project = selectedProject else { return }
        if manager.start(agent, projectName: project.name, directory: project.path, prompt: prompt) != nil {
            prompt = ""
        }
    }
}

// MARK: - Pieces

/// A starter card per installed agent, styled like the chat welcome cards.
private struct AgentStarterCard: View {
    let agent: DetectedAgent
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ChatMetrics.cardCorner, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                AgentMonogram(agent: agent.agent, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.agent.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.daPrimaryText)
                        .lineLimit(1)
                    Text(agent.version.map { "v\($0)" } ?? agent.agent.executables[0])
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Color.daTertiaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                ChatIcon(.arrowUpRight, size: 11.5)
                    .foregroundStyle(Color.daTertiaryText)
                    .opacity(isHovered ? 1 : 0)
                    .offset(x: isHovered ? 0 : -4, y: isHovered ? 0 : 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .chatSurface(cornerRadius: ChatMetrics.cardCorner)
            .overlay(shape.strokeBorder(Color.daAccent.opacity(isHovered ? 0.45 : 0), lineWidth: 1))
            .background(shape.fill(Color.primary.opacity(isHovered ? 0.03 : 0)))
            .shadow(color: .black.opacity(isHovered ? 0.10 : 0), radius: 10, y: 4)
            .offset(y: isHovered ? -2 : 0)
            .contentShape(shape)
        }
        .buttonStyle(AgentPressableStyle())
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.22), value: isHovered)
        .help(agent.path ?? "")
    }
}

private struct AgentComposerChip: View {
    let icon: ChatGlyph
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            ChatIcon(icon, size: 12.5)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.daSecondaryText)
                .lineLimit(1)
            ChatIcon(.chevronDown, size: 9)
                .foregroundStyle(Color.daMutedText)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .contentShape(Capsule())
    }
}

private struct AgentHoverCircle: View {
    @State private var isHovered = false

    var body: some View {
        Circle()
            .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct AgentPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Fades and lifts each element in, one after another.
private struct AgentEntryStagger: ViewModifier {
    let isVisible: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(.snappy(duration: 0.4).delay(Double(index) * 0.045), value: isVisible)
    }
}
