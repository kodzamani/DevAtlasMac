import SwiftUI
import AppKit

/// The floating list above the composer: matching projects, a project's numbered actions,
/// or slash commands. The highlighted row follows `chatVM.suggestionIndex`.
struct ChatSuggestionList: View {
    @ObservedObject var chatVM: ChatViewModel

    static let rowHeight: CGFloat = 44
    static let headerHeight: CGFloat = 24
    static let rowSpacing: CGFloat = 2
    static let maxVisibleRows = 6

    /// Where the pointer was when it last moved a row into the highlight. Rows slide under a
    /// resting pointer while the keyboard scrolls the list; that must not steal the selection.
    @State private var lastPointer: CGPoint?

    /// Rows, with a header wherever the kind changes. The first header is pinned above the
    /// scrolling area instead, so it stays visible while the keyboard scrolls the list.
    private var entries: [Entry] {
        var result: [Entry] = []
        var previousKind = chatVM.suggestions.first.map(Kind.init)
        for (index, suggestion) in chatVM.suggestions.enumerated() {
            let kind = Kind(suggestion)
            if kind != previousKind {
                result.append(.header(kind, firstIndex: index))
                previousKind = kind
            }
            result.append(.row(suggestion, index: index))
        }
        return result
    }

    var body: some View {
        let entries = entries
        VStack(alignment: .leading, spacing: 0) {
            if let first = chatVM.suggestions.first {
                sectionHeader(Kind(first))
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                Divider().opacity(chatVM.suggestions.count > Self.maxVisibleRows ? 0.5 : 0)
            }
            scrollingRows(entries)
        }
        .chatGlass(cornerRadius: 16)
    }

    private func scrollingRows(_ entries: [Entry]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Self.rowSpacing) {
                    ForEach(entries) { entry in
                        switch entry {
                        case .header(let kind, _):
                            sectionHeader(kind)
                        case .row(let suggestion, let index):
                            row(suggestion, index: index)
                                .id(suggestion.id)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
            .frame(height: listHeight(for: entries))
            .daOnChange(of: chatVM.suggestionIndex) { _, index in
                guard chatVM.suggestions.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(chatVM.suggestions[index].id)
                }
            }
        }
    }

    /// Fits the content up to six rows, then scrolls.
    private func listHeight(for entries: [Entry]) -> CGFloat {
        var height: CGFloat = 8 // vertical padding
        var rows = 0
        var count = 0
        for entry in entries {
            switch entry {
            case .header:
                height += Self.headerHeight
            case .row:
                guard rows < Self.maxVisibleRows else { continue }
                rows += 1
                height += Self.rowHeight
            }
            count += 1
        }
        height += CGFloat(max(0, count - 1)) * Self.rowSpacing
        // A list taller than six rows peeks the next one so it reads as scrollable.
        if chatVM.suggestions.count > Self.maxVisibleRows { height += Self.rowHeight * 0.4 }
        return height
    }

    // MARK: - Pieces

    private func sectionHeader(_ kind: Kind) -> some View {
        Text(kind.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: Self.headerHeight, alignment: .bottomLeading)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ suggestion: ChatSuggestion, index: Int) -> some View {
        let isSelected = index == chatVM.suggestionIndex
        return Button {
            chatVM.accept(suggestion)
        } label: {
            ChatSuggestionRow(suggestion: suggestion, isSelected: isSelected)
                .frame(height: Self.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .daContinuousHover { phase in
            guard case .active = phase else { return }
            let pointer = NSEvent.mouseLocation
            defer { lastPointer = pointer }
            guard let lastPointer, lastPointer != pointer else { return }
            if chatVM.suggestionIndex != index { chatVM.suggestionIndex = index }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Entries

    enum Kind: Hashable {
        case projects, actions, commands

        init(_ suggestion: ChatSuggestion) {
            switch suggestion {
            case .project: self = .projects
            case .action: self = .actions
            case .command: self = .commands
            }
        }

        var title: String {
            switch self {
            case .projects: return "chat.suggest.projects".localized
            case .actions: return "chat.suggest.actions".localized
            case .commands: return "chat.suggest.commands".localized
            }
        }
    }

    private enum Entry: Identifiable {
        case header(Kind, firstIndex: Int)
        case row(ChatSuggestion, index: Int)

        var id: String {
            switch self {
            case .header(let kind, let firstIndex): return "header:\(kind):\(firstIndex)"
            case .row(let suggestion, _): return suggestion.id
            }
        }
    }
}

// MARK: - Row

private struct ChatSuggestionRow: View {
    let suggestion: ChatSuggestion
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 11) {
            leading
            content
            Spacer(minLength: 8)
            trailing
            ChatKeyCap(text: "↩")
                .opacity(isSelected ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(isSelected ? 0.08 : 0))
        )
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    @ViewBuilder
    private var leading: some View {
        switch suggestion {
        case .project(let project, _):
            ProjectFolderIcon(project: project, size: 26, isInteractive: false)
                .frame(width: 28)
        case .action(let action, let number):
            HStack(spacing: 8) {
                ChatKeyCap(text: "\(number)")
                    .fixedSize()
                    .frame(minWidth: 24)
                ChatIconTile(glyph: action.glyph, tint: Color(hex: action.tintHex))
            }
        case .command(let command):
            ChatIconTile(glyph: command.glyph, tint: Color.daAccent)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch suggestion {
        case .project(let project, let matchedIndices):
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.highlightedName(project.name, matched: matchedIndices))
                    .lineLimit(1)
                Text((project.path as NSString).abbreviatingWithTildeInPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .action(let action, _):
            Text(action.title)
                .font(.system(size: 13.5))
                .foregroundStyle(action.isDestructive ? Color.red : Color.daPrimaryText)
                .lineLimit(1)
        case .command(let command):
            HStack(spacing: 8) {
                Text(command.token)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.daPrimaryText)
                Text(command.title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if case .project(let project, _) = suggestion {
            ChatTypePill(text: project.projectType, color: Color(hex: project.displayIconColor))
        }
    }

    /// The project name with the typed characters in bold accent.
    static func highlightedName(_ name: String, matched: Set<Int>) -> AttributedString {
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
