import SwiftUI

/// Past conversations, newest first. Opened from the clock button in the chat header.
struct ChatHistoryPopover: View {
    let chatVM: ChatViewModel

    @Environment(\.dismiss) private var dismiss

    private static let rowHeight: CGFloat = 48
    private static let maxListHeight: CGFloat = 380

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(Color.daCardEdge)
                .frame(height: 1)

            if chatVM.conversations.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("chat.history.title".localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.daPrimaryText)

            Spacer(minLength: 8)

            Button {
                chatVM.newConversation()
                dismiss()
            } label: {
                ChatIconLabel(title: "chat.header.newChat".localized, glyph: .compose)
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(ChatChipButtonStyle())
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            ChatIcon(.chat, size: 21.5)
                .foregroundStyle(Color.daMutedText)
            Text("chat.history.empty".localized)
                .font(.system(size: 12))
                .foregroundStyle(Color.daTertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }

    private var list: some View {
        let count = chatVM.conversations.count
        let height = min(CGFloat(count) * (Self.rowHeight + 2) + 12, Self.maxListHeight)

        return ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(chatVM.conversations) { conversation in
                    ChatHistoryRow(
                        conversation: conversation,
                        isCurrent: conversation.id == chatVM.current.id,
                        height: Self.rowHeight
                    ) {
                        chatVM.selectConversation(conversation.id)
                        dismiss()
                    } onDelete: {
                        withAnimation(.snappy(duration: 0.22)) {
                            chatVM.deleteConversation(conversation.id)
                        }
                    }
                }
            }
            .padding(6)
        }
        .frame(height: height)
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct ChatHistoryRow: View {
    let conversation: ChatConversation
    let isCurrent: Bool
    let height: CGFloat
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var title: String {
        let title = conversation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "chat.history.untitled".localized : title
    }

    private var detail: String {
        let date = conversation.updatedAt.formatted(.relative(presentation: .named))
        let count = "chat.history.messageCount".localized(conversation.messages.count)
        return "\(date) · \(count)"
    }

    var body: some View {
        HStack(spacing: 10) {
            ChatIcon(.chat, size: 14)
                .foregroundStyle(isCurrent ? Color.daAccent : Color.daTertiaryText)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(Color.daPrimaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daTertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if isHovered {
                Button(action: onDelete) {
                    ChatIcon(.trash, size: 12.5)
                        .foregroundStyle(Color.red.opacity(0.85))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("chat.history.delete".localized)
                .accessibilityLabel("chat.history.delete".localized)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowFill)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "chat.history.delete".localized, onDelete)
    }

    private var rowFill: Color {
        if isCurrent { return Color.daAccent.opacity(0.14) }
        return Color.primary.opacity(isHovered ? 0.05 : 0)
    }
}
