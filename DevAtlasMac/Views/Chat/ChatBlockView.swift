import SwiftUI

/// Renders one block of a chat message. Every `ChatContent` case has a view here;
/// the rich result cards live in ChatResultCards.swift.
struct ChatBlockView: View {
    let block: ChatBlock
    let message: ChatMessage
    let chatVM: ChatViewModel

    var body: some View {
        content
            .frame(maxWidth: ChatMetrics.columnWidth - 40, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch block.content {
        case .text(let markdown):
            ChatMarkdownText(markdown: markdown)
        case .notice(let notice):
            ChatNoticeRow(notice: notice)
        case .project(let project):
            ChatProjectCard(project: project) {
                chatVM.perform(.openInDevAtlas, in: message)
            }
        case .actions(let actions):
            if followsProjectCard {
                ChatActionGrid(actions: actions) { chatVM.perform($0, in: message) }
            } else {
                ChatFollowUpChips(actions: actions) { chatVM.perform($0, in: message) }
            }
        case .projectList(let title, let projects):
            ChatProjectListView(title: title, projects: projects) { chatVM.selectProject($0) }
        case .scripts(let scripts):
            ChatScriptListView(scripts: scripts) { chatVM.runScript($0, in: message) }
        case .confirm(let confirmation):
            ChatConfirmCard(confirmation: confirmation) { confirmed in
                chatVM.resolveConfirmation(blockID: block.id, in: message.id, confirmed: confirmed)
            }
        case .git(let payload):
            ChatGitCard(payload: payload)
        case .codeStats(let payload):
            ChatCodeStatsCard(payload: payload)
        case .dependencies(let payload):
            ChatDependenciesCard(payload: payload)
        case .unusedCode(let payload):
            ChatUnusedCodeCard(payload: payload)
        case .cache(let payload):
            ChatCacheCard(payload: payload)
        case .readme(let payload):
            ChatReadmeCard(payload: payload)
        case .workspaceStats(let payload):
            ChatWorkspaceStatsCard(payload: payload)
        }
    }

    /// Actions right under a project card are its menu; anywhere else they are follow-ups.
    private var followsProjectCard: Bool {
        guard let index = message.blocks.firstIndex(where: { $0.id == block.id }), index > 0 else { return false }
        if case .project = message.blocks[index - 1].content { return true }
        return false
    }
}

// MARK: - Text

private struct ChatMarkdownText: View {
    let markdown: String

    var body: some View {
        if Self.needsBlockRendering(markdown) {
            CustomMarkdownView(content: markdown)
                .padding(.horizontal, -10)
                .padding(.bottom, -10)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(Self.attributed(markdown))
                .font(.system(size: 13.5))
                .foregroundStyle(Color.daPrimaryText)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func attributed(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }

    /// Headings, lists, code fences and tables need the full renderer.
    static func needsBlockRendering(_ markdown: String) -> Bool {
        markdown.split(separator: "\n", omittingEmptySubsequences: true).contains { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") || line.hasPrefix("```") || line.hasPrefix("|") || line.hasPrefix("> ") { return true }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return true }
            if let dot = line.firstIndex(of: "."), dot > line.startIndex,
               line[line.startIndex..<dot].allSatisfy(\.isNumber),
               line[line.index(after: dot)...].hasPrefix(" ") { return true }
            return false
        }
    }
}

// MARK: - Notice

private struct ChatNoticeRow: View {
    let notice: ChatNotice

    private var glyph: ChatGlyph {
        switch notice.kind {
        case .success: return .checkCircle
        case .info: return .info
        case .warning: return .warning
        case .error: return .xCircle
        }
    }

    private var tint: Color {
        switch notice.kind {
        case .success: return .daGreen
        case .info: return .daAccent
        case .warning: return .orange
        case .error: return .red
        }
    }

    var body: some View {
        HStack(alignment: notice.detail == nil ? .center : .top, spacing: 10) {
            ChatIcon(glyph, size: 16)
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = notice.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.daSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.09))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Project card

private struct ChatProjectCard: View {
    let project: ProjectInfo
    let onOpen: () -> Void

    @State private var isNameHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onOpen) {
                ProjectFolderIcon(project: project, size: 44, isInteractive: false)
            }
            .buttonStyle(.plain)
            .cursor(.pointingHand)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Button(action: onOpen) {
                    HStack(spacing: 5) {
                        Text(project.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.daPrimaryText)
                            .lineLimit(1)
                            .underline(isNameHovered, color: Color.daPrimaryText.opacity(0.4))
                        ChatIcon(.arrowUpRight, size: 11.5)
                            .foregroundStyle(Color.daTertiaryText)
                            .opacity(isNameHovered ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .cursor(.pointingHand)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) { isNameHovered = hovering }
                }
                .help("quickSearch.openInDevAtlas".localized)

                Text(project.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.daTertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(project.path)

                FlowLayout(spacing: 6) {
                    ChatTypePill(text: project.projectType, color: Color(hex: project.displayIconColor))
                    if project.language != project.projectType {
                        ChatTypePill(text: project.language, color: .daAccent)
                    }
                    if let branch = project.gitBranch, !branch.isEmpty {
                        ChatInfoPill(glyph: .branch, text: branch)
                    }
                }
                .padding(.top, 2)

                HStack(spacing: 12) {
                    ChatIconLabel(title: ChatRelativeDate.string(for: project.lastModified), glyph: .clock)
                    if let files = project.totalFiles, files > 0 {
                        ChatIconLabel(title: "chat.card.project.files".localized(files.formatted()), glyph: .doc)
                    }
                    if let lines = project.totalLines, lines > 0 {
                        ChatIconLabel(title: "stats.linesValue".localized(lines.formatted()), glyph: .lines)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.daTertiaryText)
                .lineLimit(1)
                .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chatSurface(cornerRadius: ChatMetrics.cardCorner)
    }
}

// MARK: - Actions

/// Numbered actions under a project card, split into labelled groups.
private struct ChatActionGrid: View {
    let actions: [ChatAction]
    let onSelect: (ChatAction) -> Void

    private struct Entry: Identifiable {
        let number: Int
        let action: ChatAction
        var id: String { action.id }
    }

    private struct Section: Identifiable {
        let group: ChatActionGroup
        let items: [Entry]
        var id: Int { group.rawValue }
    }

    private var sections: [Section] {
        let entries = actions.enumerated().map { Entry(number: $0.offset + 1, action: $0.element) }
        return ChatActionGroup.allCases.compactMap { group in
            let items = entries.filter { $0.action.group == group }
            return items.isEmpty ? nil : Section(group: group, items: items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sections) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.group.title)
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.daMutedText)
                        .padding(.leading, 4)

                    VStack(spacing: 1) {
                        ForEach(entry.items) { item in
                            Button { onSelect(item.action) } label: {
                                ChatActionRowLabel(action: item.action, number: item.number)
                            }
                            .buttonStyle(ChatHoverRowStyle(cornerRadius: 9))
                            .cursor(.pointingHand)
                            .help(item.action.title)
                        }
                    }
                    .padding(3)
                    .chatSurface(cornerRadius: ChatMetrics.cardCorner)
                }
            }
        }
    }
}

private struct ChatActionRowLabel: View {
    let action: ChatAction
    let number: Int

    var body: some View {
        HStack(spacing: 10) {
            ChatIconTile(glyph: action.glyph, tint: Color(hex: action.tintHex), size: 24)
            Text(action.title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(action.isDestructive ? Color.red : Color.daPrimaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            ChatKeyCap(text: "\(number)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Numbered follow-up chips after a result.
private struct ChatFollowUpChips: View {
    let actions: [ChatAction]
    let onSelect: (ChatAction) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                Button { onSelect(action) } label: {
                    HStack(spacing: 6) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.daTertiaryText)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(Color.primary.opacity(0.07)))
                        ChatIcon(action.glyph, size: 12)
                            .foregroundStyle(action.isDestructive ? Color.red : Color(hex: action.tintHex))
                        Text(action.title)
                            .lineLimit(1)
                    }
                    .padding(.leading, -5)
                }
                .buttonStyle(ChatChipButtonStyle(tint: Color(hex: action.tintHex), isDestructive: action.isDestructive))
                .cursor(.pointingHand)
            }
        }
    }
}

// MARK: - Project list

private struct ChatProjectListView: View {
    let title: String
    let projects: [ProjectInfo]
    let onSelect: (ProjectInfo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
                    .accessibilityAddTraits(.isHeader)
            }

            if projects.isEmpty {
                ChatCardEmptyState(glyph: .folder, message: "chat.card.projectList.empty".localized)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                        if index > 0 {
                            Color.clear.frame(height: 2)
                        }
                        Button { onSelect(project) } label: {
                            row(project)
                        }
                        .buttonStyle(ChatHoverRowStyle(cornerRadius: 9))
                        .cursor(.pointingHand)
                    }
                }
                .padding(4)
                .chatSurface(cornerRadius: ChatMetrics.cardCorner)
            }
        }
    }

    private func row(_ project: ProjectInfo) -> some View {
        HStack(spacing: 10) {
            ProjectFolderIcon(project: project, size: 24, isInteractive: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.daPrimaryText)
                    .lineLimit(1)
                Text(project.path)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daTertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            ChatTypePill(text: project.projectType, color: Color(hex: project.displayIconColor))
            ChatIcon(.chevronRight, size: 11.5)
                .foregroundStyle(Color.daMutedText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Scripts

private struct ChatScriptListView: View {
    let scripts: [ChatScript]
    let onRun: (ChatScript) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(scripts.enumerated()), id: \.element.id) { index, script in
                if index > 0 {
                    Color.clear.frame(height: 2)
                }
                Button { onRun(script) } label: {
                    HStack(spacing: 10) {
                        ChatIconTile(glyph: .play, tint: Color(hex: "30B158"), size: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(script.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Color.daPrimaryText)
                                .lineLimit(1)
                            Text(script.command)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.daTertiaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer(minLength: 8)
                        ChatIcon(.chevronRight, size: 11.5)
                            .foregroundStyle(Color.daMutedText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(ChatHoverRowStyle(cornerRadius: 9))
                .cursor(.pointingHand)
                .help(script.command)
            }
        }
        .padding(4)
        .chatSurface(cornerRadius: ChatMetrics.cardCorner)
    }
}

// MARK: - Confirmation

private struct ChatConfirmCard: View {
    let confirmation: ChatConfirmation
    let onResolve: (Bool) -> Void

    private var tint: Color { confirmation.isDestructive ? .red : .orange }
    private var isPending: Bool { confirmation.state == .pending }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ChatIcon(.warning, size: 16.5)
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint.opacity(0.14)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(confirmation.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.daPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(confirmation.message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.daSecondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                if isPending {
                    Button("common.cancel".localized) { onResolve(false) }
                        .buttonStyle(ChatChipButtonStyle())
                        .cursor(.pointingHand)
                    Button { onResolve(true) } label: {
                        Text(confirmation.confirmLabel)
                    }
                    .buttonStyle(ChatProminentButtonStyle(tint: confirmation.isDestructive ? .red : .daAccent))
                    .cursor(.pointingHand)
                } else {
                    resolvedLabel
                        .transition(.opacity)
                }
            }
            .animation(.snappy(duration: 0.22), value: confirmation.state)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chatSurface(cornerRadius: ChatMetrics.cardCorner)
        .overlay(
            RoundedRectangle(cornerRadius: ChatMetrics.cardCorner, style: .continuous)
                .strokeBorder(tint.opacity(isPending ? 0.3 : 0), lineWidth: 0.75)
                .allowsHitTesting(false)
        )
        .disabled(!isPending)
    }

    private var resolvedLabel: some View {
        let confirmed = confirmation.state == .confirmed
        return ChatIconLabel(
            title: confirmed ? "chat.confirm.confirmed".localized : "chat.confirm.cancelled".localized,
            glyph: confirmed ? .checkCircle : .xCircle
        )
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(confirmed ? Color.daGreen : Color.daTertiaryText)
        .frame(minHeight: 30)
    }
}

/// Filled capsule for a primary choice.
private struct ChatProminentButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, tint: tint)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let tint: Color
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 30)
                .background(Capsule().fill(tint.gradient))
                .overlay(Capsule().fill(Color.white.opacity(isHovered ? 0.1 : 0)))
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}
