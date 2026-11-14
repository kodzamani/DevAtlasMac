import SwiftUI

/// One turn in the thread: a right-aligned bubble for the user, an avatar and rich blocks for the assistant.
struct ChatMessageRow: View {
    let message: ChatMessage
    let chatVM: ChatViewModel
    /// The last row keeps its toolbar visible, like most chat apps.
    var isLast: Bool = false

    @State private var isHovered = false

    private var isRunning: Bool {
        if case .running = message.status { return true }
        return false
    }

    private var isToolbarVisible: Bool {
        guard !isRunning else { return false }
        return isHovered || (isLast && message.role == .assistant)
    }

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            switch message.role {
            case .user:
                userBody
            case .assistant:
                assistantBody
            }

            ChatMessageToolbar(message: message, chatVM: chatVM, isVisible: isToolbarVisible)
                .padding(.leading, message.role == .assistant ? ChatAssistantAvatar.size + 12 : 0)
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isToolbarVisible)
    }

    // MARK: User

    private var userText: String {
        for block in message.blocks {
            if case .text(let text) = block.content, !text.isEmpty { return text }
        }
        return message.plainText
    }

    private var userBody: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 80)
            Text(verbatim: userText)
                .font(.system(size: 13.5))
                .foregroundStyle(Color.white)
                .lineSpacing(2)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: ChatMetrics.bubbleCorner, style: .continuous)
                        .fill(Color.daAccent)
                )
                .frame(maxWidth: 520, alignment: .trailing)
        }
    }

    // MARK: Assistant

    private var assistantBody: some View {
        HStack(alignment: .top, spacing: 12) {
            ChatAssistantAvatar(isWorking: isRunning)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(message.blocks) { block in
                    ChatBlockView(block: block, message: message, chatVM: chatVM)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                }

                switch message.status {
                case .running(let label):
                    ChatTypingIndicator(label: label)
                        .frame(minHeight: ChatAssistantAvatar.size)
                        .transition(.opacity)
                case .failed:
                    ChatFailedNote()
                        .transition(.opacity)
                case .done:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, message.blocks.isEmpty ? 0 : 3)
            .animation(.snappy(duration: 0.25), value: message.blocks.count)
            .animation(.easeOut(duration: 0.2), value: message.status)
        }
    }
}

// MARK: - Avatar

/// The assistant's mark: the app's chat glyph in a small card circle.
struct ChatAssistantAvatar: View {
    static let size: CGFloat = 26
    var isWorking: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(Color.daCard)
            LineGlyphView(glyph: .chat, isSelected: true)
                .scaleEffect(0.78)
        }
        .frame(width: Self.size, height: Self.size)
        .overlay {
            if isWorking {
                ChatAvatarPulse()
            }
        }
    }
}

/// A soft accent ring that breathes while the assistant is working.
private struct ChatAvatarPulse: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * 2.6) + 1) / 2
            Circle()
                .strokeBorder(Color.daAccent.opacity(0.25 + 0.35 * phase), lineWidth: 1.2)
                .scaleEffect(1 + 0.08 * phase)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Running / failed

/// Three bouncing dots followed by a shimmering status label.
struct ChatTypingIndicator: View {
    let label: String

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        let wave = max(0, sin(t * 2 * .pi * 1.2 - Double(index) * 0.7))
                        Circle()
                            .fill(Color.daAccent)
                            .frame(width: 6, height: 6)
                            .opacity(0.35 + 0.65 * wave)
                            .offset(y: -3 * wave)
                    }
                }
                .frame(height: 12)

                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundStyle(shimmer(at: t))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func shimmer(at t: TimeInterval) -> LinearGradient {
        // Sweeps a highlight from left to right every ~1.8 s.
        let progress = (t.truncatingRemainder(dividingBy: 1.8)) / 1.8
        let center = -0.3 + progress * 1.6
        return LinearGradient(
            stops: [
                .init(color: Color.daTertiaryText, location: 0),
                .init(color: Color.daTertiaryText, location: max(0, center - 0.18)),
                .init(color: Color.daPrimaryText, location: min(1, max(0, center))),
                .init(color: Color.daTertiaryText, location: min(1, center + 0.18)),
                .init(color: Color.daTertiaryText, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct ChatFailedNote: View {
    var body: some View {
        HStack(spacing: 5) {
            ChatIcon(.warning, size: 12)
            Text("chat.message.failed".localized)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.red)
    }
}

// MARK: - Toolbar

/// Copy + timestamp under a message. Always takes its height so hovering never shifts the layout.
private struct ChatMessageToolbar: View {
    let message: ChatMessage
    let chatVM: ChatViewModel
    let isVisible: Bool

    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 4) {
            if message.role == .user { timestamp }

            ChatToolbarButton(
                glyph: didCopy ? .check : .copy,
                help: "chat.message.copy".localized,
                tint: didCopy ? Color.daGreen : nil
            ) {
                chatVM.copy(message)
                withAnimation(.easeOut(duration: 0.12)) { didCopy = true }
                resetTask?.cancel()
                resetTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.12)) { didCopy = false }
                }
            }

            if message.role == .assistant { timestamp }
        }
        .frame(height: 22)
        .opacity(isVisible || didCopy ? 1 : 0)
        .allowsHitTesting(isVisible || didCopy)
        .onDisappear { resetTask?.cancel() }
    }

    private var timestamp: some View {
        Text(message.date.formatted(date: .omitted, time: .shortened))
            .font(.system(size: 11))
            .foregroundStyle(Color.daMutedText)
            .monospacedDigit()
            .padding(.horizontal, 4)
    }
}

private struct ChatToolbarButton: View {
    let glyph: ChatGlyph
    let help: String
    var tint: Color?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ChatIcon(glyph, size: 13)
                .foregroundStyle(tint ?? (isHovered ? Color.daPrimaryText : Color.daTertiaryText))
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(isHovered ? 0.07 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(help)
        .accessibilityLabel(help)
    }
}
