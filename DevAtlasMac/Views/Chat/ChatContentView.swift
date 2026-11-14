import SwiftUI

/// The Chat tab: a header, the message thread (or a welcome screen) and the composer pinned to the bottom.
struct ChatContentView: View {
    let viewModel: AppViewModel
    @Bindable var chatVM: ChatViewModel

    @State private var isScrolled = false

    private static let bottomAnchorID = "chat.thread.bottom"
    private static let scrollSpace = "chat.thread.scroll"

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if chatVM.messages.isEmpty {
                    ChatEmptyStateView(chatVM: chatVM)
                        .transition(.opacity)
                } else {
                    thread
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.2), value: chatVM.messages.isEmpty)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChatComposerView(chatVM: chatVM)
                    .frame(maxWidth: ChatMetrics.columnWidth)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await chatVM.load() }
        .onChange(of: chatVM.messages.isEmpty) { _, isEmpty in
            if isEmpty { isScrolled = false }
        }
    }

    // MARK: - Thread

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 22) {
                    ForEach(chatVM.messages) { message in
                        ChatMessageRow(
                            message: message,
                            chatVM: chatVM,
                            isLast: message.id == chatVM.messages.last?.id
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)),
                            removal: .opacity
                        ))
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                }
                .animation(.snappy(duration: 0.28), value: chatVM.messages.count)
                .frame(maxWidth: ChatMetrics.columnWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ChatScrollOffsetKey.self,
                            value: geo.frame(in: .named(Self.scrollSpace)).minY
                        )
                    }
                )
                .id(chatVM.current.id)
            }
            .coordinateSpace(name: Self.scrollSpace)
            .scrollBounceBehavior(.basedOnSize)
            .mask(threadFadeMask)
            .onPreferenceChange(ChatScrollOffsetKey.self) { offset in
                let scrolled = offset < -4
                if scrolled != isScrolled { isScrolled = scrolled }
            }
            .onAppear { scrollToBottom(proxy, animated: false) }
            .onChange(of: chatVM.current.id) {
                scrollToBottom(proxy, animated: false)
            }
            .onChange(of: chatVM.messages.count) {
                scrollToBottom(proxy, animated: true)
            }
            .onChange(of: chatVM.messages.last) {
                scrollToBottom(proxy, animated: true)
            }
            .onChange(of: chatVM.activeProject?.id) {
                scrollToBottom(proxy, animated: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .chatThreadNeedsScroll)) { _ in
                scrollToBottom(proxy, animated: true)
            }
        }
    }

    /// Fades the thread out just above the composer, so messages slide under it instead of being cut off.
    /// The reader is sized to the safe area, so whatever scrolls beneath the composer inset is masked away.
    private var threadFadeMask: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                Rectangle().fill(Color.black)
                LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
            }
        }
        .allowsHitTesting(false)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        // Wait a run loop so freshly inserted rows have a layout, then once more
        // after the insert animation, when tall cards have their final height.
        for delay in [0.0, 0.32] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if animated {
                    withAnimation(.snappy(duration: 0.3)) {
                        proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                    }
                } else {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Preference keys

private struct ChatScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Header pieces

/// The project the conversation is currently about.
struct ChatProjectPill: View {
    let project: ProjectInfo

    var body: some View {
        HStack(spacing: 6) {
            ProjectFolderIcon(project: project, size: 15, isInteractive: false)
            Text(project.name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.daSecondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize()
        .padding(.leading, 6)
        .padding(.trailing, 9)
        .frame(height: 24)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .help(project.path)
    }
}

// MARK: - Toolbar pieces

/// Conversation title and active project, shown in the window toolbar.
struct ChatToolbarTitle: View {
    let chatVM: ChatViewModel

    private var title: String {
        let title = chatVM.current.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "chat.header.newChat".localized : title
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color.daPrimaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .contentTransition(.opacity)

            if let project = chatVM.activeProject {
                ChatProjectPill(project: project)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .padding(.leading, 12)
        .animation(.snappy(duration: 0.22), value: chatVM.activeProject?.id)
    }
}

/// History popover button and "new chat" button for the window toolbar.
struct ChatToolbarActions: View {
    @Bindable var chatVM: ChatViewModel
    @State private var isHistoryPresented = false

    var body: some View {
        Button {
            isHistoryPresented.toggle()
        } label: {
            ChatIcon(.clock, size: 16)
        }
        .help("chat.header.history".localized)
        .popover(isPresented: $isHistoryPresented, arrowEdge: .bottom) {
            ChatHistoryPopover(chatVM: chatVM)
        }

        Button {
            chatVM.newConversation()
        } label: {
            ChatIcon(.compose, size: 16)
        }
        .help("chat.header.newChat".localized)
    }
}

#Preview {
    let appVM = AppViewModel()
    return ChatContentView(viewModel: appVM, chatVM: ChatViewModel(appViewModel: appVM))
        .frame(width: 900, height: 640)
}
