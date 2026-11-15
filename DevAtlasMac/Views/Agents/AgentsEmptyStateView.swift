import SwiftUI
import AppKit
import Carbon.HIToolbox

/// The Agents tab before any session is open, laid out like a new chat:
/// a greeting, agent and prompt starter cards, and a composer at the bottom.
struct AgentsEmptyStateView: View {
    let viewModel: AppViewModel

    @State private var selectedProjectID: String?
    @State private var prompt = ""
    @State private var hasAppeared = false
    @State private var suggestionIndex = 0
    @State private var areSuggestionsDismissed = false
    @State private var isPickerOpen = false
    @State private var wasMentionOpenedByChip = false
    @State private var suppressNextIndexReset = false
    @State private var keyMonitor = AgentComposerKeyMonitor()
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private static let suggestionLimit = 20

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

    // MARK: - Project Suggestion Matching

    private struct MentionToken: Equatable {
        let range: Range<String.Index>
        let query: String
    }

    private enum SuggestionMode: Equatable {
        case mention(MentionToken)
        case picker(query: String)
        case inline(query: String)
    }

    /// Detects a trailing `@` or `@query` token preceded by start-of-string or whitespace.
    private var activeMention: MentionToken? {
        guard let atIndex = prompt.lastIndex(of: "@") else { return nil }
        if atIndex > prompt.startIndex {
            let before = prompt[prompt.index(before: atIndex)]
            guard before.isWhitespace || before.isNewline else { return nil }
        }
        let afterStart = prompt.index(after: atIndex)
        let tail = prompt[afterStart...]
        guard !tail.contains(where: { $0.isWhitespace || $0.isNewline }) else { return nil }
        return MentionToken(range: atIndex..<prompt.endIndex, query: String(tail))
    }

    private var suggestionMode: SuggestionMode? {
        if let mention = activeMention {
            return .mention(mention)
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if isPickerOpen {
            return .picker(query: trimmed)
        }
        guard !trimmed.isEmpty, !prompt.contains("\n") else { return nil }
        return .inline(query: trimmed)
    }

    private var currentSuggestions: [QuickSearchMatch] {
        guard let mode = suggestionMode else { return [] }
        switch mode {
        case .mention(let token):
            if token.query.isEmpty {
                return projects.prefix(Self.suggestionLimit).map {
                    QuickSearchMatch(project: $0, score: 0, matchedIndices: [])
                }
            }
            return matchProjects(token.query, allowExtendedFields: true)

        case .picker(let query):
            if query.isEmpty {
                return projects.prefix(Self.suggestionLimit).map {
                    QuickSearchMatch(project: $0, score: 0, matchedIndices: [])
                }
            }
            return matchProjects(query, allowExtendedFields: true)

        case .inline(let query):
            return matchProjects(query, allowExtendedFields: false)
        }
    }

    private var suggestionHeaderTitle: String {
        switch suggestionMode {
        case .mention(let token) where token.query.isEmpty:
            return "chat.suggest.recentProjects".localized
        case .picker(let query) where query.isEmpty:
            return "chat.suggest.recentProjects".localized
        default:
            return "chat.suggest.projects".localized
        }
    }

    private var isSuggestionListVisible: Bool {
        !areSuggestionsDismissed && !currentSuggestions.isEmpty
    }

    private func matchProjects(_ query: String, allowExtendedFields: Bool) -> [QuickSearchMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = trimmed.lowercased()
        let hasSpaces = trimmed.contains(" ")

        var found: [QuickSearchMatch] = []
        for project in projects {
            if hasSpaces && !allowExtendedFields {
                if project.name.localizedCaseInsensitiveContains(trimmed),
                   let match = QuickSearchModel.match(trimmed, in: project.name) {
                    found.append(QuickSearchMatch(project: project, score: match.score, matchedIndices: match.indices))
                }
                continue
            }

            if let nameMatch = QuickSearchModel.match(trimmed, in: project.name) {
                found.append(QuickSearchMatch(project: project, score: nameMatch.score, matchedIndices: nameMatch.indices))
            } else if allowExtendedFields {
                let otherFields = [project.path, project.projectType] + project.tags
                if otherFields.contains(where: { $0.lowercased().contains(needle) }) {
                    found.append(QuickSearchMatch(project: project, score: 50, matchedIndices: []))
                }
            }
        }

        return Array(
            found.enumerated()
                .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
                .map(\.element)
                .prefix(Self.suggestionLimit)
        )
    }

    // MARK: - Body

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

                    AgentPromptSuggestions(
                        onSelect: usePrompt,
                        onBrowse: { viewModel.selectedTab = .aiPrompts }
                    )
                    .padding(.top, 32)
                    .modifier(AgentEntryStagger(isVisible: hasAppeared, index: 5))
                }
                .frame(maxWidth: ChatMetrics.columnWidth)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSuggestionListVisible {
                        _ = handleEscape()
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .overlay(alignment: .bottom) {
                if isSuggestionListVisible {
                    AgentProjectSuggestionList(
                        title: suggestionHeaderTitle,
                        matches: currentSuggestions,
                        selectedProjectID: selectedProject?.id,
                        highlightedIndex: min(suggestionIndex, max(0, currentSuggestions.count - 1)),
                        onHoverIndex: { suggestionIndex = $0 },
                        onSelect: { accept($0.project) }
                    )
                    .frame(maxWidth: ChatMetrics.columnWidth)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.snappy(duration: 0.22), value: isSuggestionListVisible)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                composer
                AgentComposerHints(isListVisible: isSuggestionListVisible)
            }
            .frame(maxWidth: ChatMetrics.columnWidth)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .background(AgentWindowReader { keyMonitor.window = $0 })
        .onAppear {
            hasAppeared = true
            if selectedProjectID == nil {
                selectedProjectID = (viewModel.selectedProject ?? viewModel.highlightedProject ?? projects.first)?.id
            }
            configureKeyMonitor()
            keyMonitor.install()
            // The field only takes focus once it is in a window.
            DispatchQueue.main.async { isFocused = true }
        }
        .onDisappear {
            keyMonitor.remove()
        }
        .onChange(of: isFocused) { _, focused in
            keyMonitor.isFocused = focused
        }
        .onChange(of: prompt) { _, _ in
            areSuggestionsDismissed = false
            if activeMention == nil {
                wasMentionOpenedByChip = false
            }
            if suppressNextIndexReset {
                suppressNextIndexReset = false
            } else {
                suggestionIndex = 0
            }
            syncKeyMonitorState()
        }
        .onChange(of: isSuggestionListVisible) { _, _ in
            syncKeyMonitorState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            guard !isFocused, let window = note.object as? NSWindow, window === keyMonitor.window,
                  window.firstResponder == nil || window.firstResponder === window
            else { return }
            isFocused = true
        }
    }

    // MARK: - Middle

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

    // MARK: - Composer

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
                .onSubmit { handleReturnSubmit() }

            HStack(spacing: 6) {
                projectButton
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

    private var projectButton: some View {
        Button {
            toggleProjectPicker()
        } label: {
            AgentComposerChip(
                project: selectedProject,
                title: selectedProject?.name ?? "agents.selectProject".localized,
                isExpanded: isSuggestionListVisible
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(projects.isEmpty)
        .help(selectedProject?.path ?? "agents.selectProject".localized)
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

    // MARK: - Actions & Keyboard Handling

    private func usePrompt(_ template: AIPromptTemplate) {
        prompt = template.prompt
        isPickerOpen = false
        wasMentionOpenedByChip = false
        isFocused = true
    }

    private func toggleProjectPicker() {
        if isSuggestionListVisible {
            _ = handleEscape()
            isFocused = true
            return
        }

        let currentIndex = projects.firstIndex(where: { $0.id == selectedProject?.id }) ?? 0
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !prompt.isEmpty {
                suppressNextIndexReset = true
                prompt = ""
            }
            isPickerOpen = true
            areSuggestionsDismissed = false
            suggestionIndex = min(currentIndex, max(0, Self.suggestionLimit - 1))
        } else {
            if activeMention == nil {
                wasMentionOpenedByChip = true
                suppressNextIndexReset = true
                prompt += (prompt.last?.isWhitespace == true) ? "@" : " @"
            }
            areSuggestionsDismissed = false
            suggestionIndex = min(currentIndex, max(0, Self.suggestionLimit - 1))
        }
        syncKeyMonitorState()
        isFocused = true
    }

    private func moveSuggestion(by offset: Int) {
        let list = currentSuggestions
        guard !list.isEmpty else { return }
        if areSuggestionsDismissed {
            areSuggestionsDismissed = false
            syncKeyMonitorState()
            return
        }
        let count = list.count
        suggestionIndex = ((suggestionIndex + offset) % count + count) % count
    }

    @discardableResult
    private func acceptHighlightedSuggestion() -> Bool {
        let list = currentSuggestions
        guard isSuggestionListVisible, !list.isEmpty else { return false }
        let safeIndex = min(suggestionIndex, list.count - 1)
        accept(list[safeIndex].project)
        return true
    }

    private func accept(_ project: ProjectInfo) {
        selectedProjectID = project.id
        switch suggestionMode {
        case .mention(let token):
            var updated = prompt
            if wasMentionOpenedByChip,
               token.range.lowerBound > updated.startIndex,
               updated[updated.index(before: token.range.lowerBound)] == " " {
                let start = updated.index(before: token.range.lowerBound)
                updated.removeSubrange(start..<token.range.upperBound)
            } else {
                updated.removeSubrange(token.range)
            }
            if updated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated = ""
            }
            prompt = updated
        case .picker, .inline, .none:
            prompt = ""
        }
        isPickerOpen = false
        wasMentionOpenedByChip = false
        areSuggestionsDismissed = false
        suggestionIndex = 0
        syncKeyMonitorState()
        isFocused = true
    }

    @discardableResult
    private func handleEscape() -> Bool {
        if isSuggestionListVisible {
            if case .mention(let token) = suggestionMode, wasMentionOpenedByChip {
                var updated = prompt
                if token.range.lowerBound > updated.startIndex,
                   updated[updated.index(before: token.range.lowerBound)] == " " {
                    let start = updated.index(before: token.range.lowerBound)
                    updated.removeSubrange(start..<token.range.upperBound)
                } else {
                    updated.removeSubrange(token.range)
                }
                prompt = updated
            }
            isPickerOpen = false
            wasMentionOpenedByChip = false
            areSuggestionsDismissed = true
            syncKeyMonitorState()
            return true
        }
        if !prompt.isEmpty {
            prompt = ""
            isPickerOpen = false
            areSuggestionsDismissed = false
            syncKeyMonitorState()
            return true
        }
        return false
    }

    private func handleReturnSubmit() {
        if acceptHighlightedSuggestion() { return }
        if let agent = composerAgent {
            launch(agent)
        }
    }

    private func configureKeyMonitor() {
        keyMonitor.onMoveSuggestion = { offset in moveSuggestion(by: offset) }
        keyMonitor.onAcceptSuggestion = { acceptHighlightedSuggestion() }
        keyMonitor.onEscape = { handleEscape() }
        keyMonitor.onSubmit = { handleReturnSubmit() }
        syncKeyMonitorState()
    }

    private func syncKeyMonitorState() {
        keyMonitor.isSuggestionListVisible = isSuggestionListVisible
        keyMonitor.canReopenSuggestions = !currentSuggestions.isEmpty && !prompt.contains("\n")
    }

    private func launch(_ agent: DetectedAgent) {
        guard let project = selectedProject else { return }
        isPickerOpen = false
        wasMentionOpenedByChip = false
        if manager.start(agent, projectName: project.name, directory: project.path, prompt: prompt) != nil {
            prompt = ""
        }
    }
}

// MARK: - Project Suggestion List

private struct AgentProjectSuggestionList: View {
    let title: String
    let matches: [QuickSearchMatch]
    let selectedProjectID: String?
    let highlightedIndex: Int
    let onHoverIndex: (Int) -> Void
    let onSelect: (QuickSearchMatch) -> Void

    private static let rowHeight: CGFloat = 44
    private static let headerHeight: CGFloat = 24
    private static let rowSpacing: CGFloat = 2
    private static let maxVisibleRows = 6

    @State private var lastPointer: CGPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .frame(height: Self.headerHeight, alignment: .bottomLeading)
                .padding(.top, 6)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().opacity(matches.count > Self.maxVisibleRows ? 0.5 : 0)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: Self.rowSpacing) {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                            row(match, index: index)
                                .id(match.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                }
                .scrollIndicators(.automatic)
                .frame(height: listHeight)
                .onChange(of: highlightedIndex) { _, index in
                    guard matches.indices.contains(index) else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(matches[index].id)
                    }
                }
            }
        }
        .chatGlass(cornerRadius: 16)
    }

    private var listHeight: CGFloat {
        let visibleCount = min(matches.count, Self.maxVisibleRows)
        var height: CGFloat = 8 + CGFloat(visibleCount) * Self.rowHeight
        height += CGFloat(max(0, visibleCount - 1)) * Self.rowSpacing
        if matches.count > Self.maxVisibleRows {
            height += Self.rowHeight * 0.4
        }
        return height
    }

    private func row(_ match: QuickSearchMatch, index: Int) -> some View {
        let isHighlighted = index == highlightedIndex
        let isCurrentProject = match.project.id == selectedProjectID
        return Button {
            onSelect(match)
        } label: {
            HStack(spacing: 11) {
                ProjectFolderIcon(project: match.project, size: 26, isInteractive: false)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(Self.highlightedName(match.project.name, matched: match.matchedIndices))
                            .lineLimit(1)
                        if isCurrentProject {
                            ChatIcon(.check, size: 11, weight: 2)
                                .foregroundStyle(Color.daAccent)
                        }
                    }
                    Text((match.project.path as NSString).abbreviatingWithTildeInPath)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                ChatTypePill(text: match.project.projectType, color: Color(hex: match.project.displayIconColor))

                ChatKeyCap(text: "↩")
                    .opacity(isHighlighted ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .frame(height: Self.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(isHighlighted ? 0.08 : 0))
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: isHighlighted)
        }
        .buttonStyle(.plain)
        .onContinuousHover { phase in
            guard case .active = phase else { return }
            let pointer = NSEvent.mouseLocation
            defer { lastPointer = pointer }
            guard let lastPointer, lastPointer != pointer else { return }
            if highlightedIndex != index { onHoverIndex(index) }
        }
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    private static func highlightedName(_ name: String, matched: Set<Int>) -> AttributedString {
        var result = AttributedString()
        for (index, character) in name.enumerated() {
            var piece = AttributedString(String(character))
            if matched.contains(index) {
                piece.font = .system(size: 13.5, weight: .bold)
                piece.foregroundColor = Color.daAccent
            } else {
                piece.font = .system(size: 13.5, weight: matched.isEmpty ? .medium : .regular)
                piece.foregroundColor = Color.daPrimaryText
            }
            result.append(piece)
        }
        return result
    }
}

// MARK: - Hints & Keyboard Monitor

private struct AgentComposerHints: View {
    let isListVisible: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(hints)
            row(Array(hints.prefix(3)))
            row(Array(hints.prefix(2)))
            Color.clear.frame(height: 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 18)
        .animation(.easeOut(duration: 0.12), value: isListVisible)
    }

    private var hints: [(keys: [String], label: String)] {
        if isListVisible {
            return [
                (["↑", "↓"], "quickSearch.hint.navigate".localized),
                (["⇥"], "chat.hint.select".localized),
                (["↩"], "chat.hint.select".localized),
                (["esc"], "chat.hint.dismiss".localized),
            ]
        }
        return [
            (["↩"], "chat.hint.send".localized),
            (["⇧", "↩"], "chat.hint.newline".localized),
            (["@"], "agents.project".localized),
        ]
    }

    private func row(_ hints: [(keys: [String], label: String)]) -> some View {
        HStack(spacing: 14) {
            ForEach(hints, id: \.label) { hint in
                ChatKeyHint(keys: hint.keys, label: hint.label)
            }
        }
        .fixedSize()
        .opacity(0.8)
    }
}

private struct AgentWindowReader: NSViewRepresentable {
    let onChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {
        nsView.onChange = onChange
    }

    final class ReaderView: NSView {
        var onChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onChange?(window)
        }
    }
}

@MainActor
private final class AgentComposerKeyMonitor {
    weak var window: NSWindow?
    var isFocused = false
    var isSuggestionListVisible = false
    var canReopenSuggestions = false

    var onMoveSuggestion: (Int) -> Void = { _ in }
    var onAcceptSuggestion: () -> Bool = { false }
    var onEscape: () -> Bool = { false }
    var onSubmit: () -> Void = {}

    private var token: Any?

    func install() {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated { self.handle(event) }
            return handled ? nil : event
        }
    }

    func remove() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard isFocused,
              let window = event.window, window === self.window, window.isKeyWindow,
              let textView = window.firstResponder as? NSTextView
        else { return false }
        if textView.hasMarkedText() { return false }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        switch Int(event.keyCode) {
        case kVK_UpArrow, kVK_DownArrow:
            guard isSuggestionListVisible || canReopenSuggestions, flags.isEmpty else { return false }
            onMoveSuggestion(event.keyCode == UInt16(kVK_UpArrow) ? -1 : 1)
            return true
        case kVK_Tab:
            guard flags.isEmpty else { return false }
            return onAcceptSuggestion()
        case kVK_Escape:
            guard flags.isEmpty else { return false }
            return onEscape()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if flags.contains(.shift) || flags.contains(.option) {
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            if flags.contains(.control) { return false }
            onSubmit()
            return true
        default:
            break
        }

        if isSuggestionListVisible, flags == .control, let key = event.charactersIgnoringModifiers {
            if key == "n" { onMoveSuggestion(1); return true }
            if key == "p" { onMoveSuggestion(-1); return true }
        }
        return false
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
    let project: ProjectInfo?
    let title: String
    var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            if let project {
                ProjectFolderIcon(project: project, size: 16, isInteractive: false)
            } else {
                ChatIcon(.folder, size: 12.5)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isExpanded ? Color.daPrimaryText : Color.daSecondaryText)
                .lineLimit(1)
            ChatIcon(.chevronDown, size: 9)
                .foregroundStyle(Color.daMutedText)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.leading, project == nil ? 9 : 7)
        .padding(.trailing, 9)
        .frame(height: 28)
        .background(
            Capsule()
                .fill(Color.primary.opacity(isExpanded ? 0.11 : (isHovered ? 0.09 : 0.06)))
        )
        .contentShape(Capsule())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isExpanded)
        .animation(.easeOut(duration: 0.12), value: isHovered)
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
