import SwiftUI
import AppKit
import Carbon.HIToolbox

/// The floating input at the bottom of the chat, with the suggestion list above it
/// and a row of key hints below.
struct ChatComposerView: View {
    @Bindable var chatVM: ChatViewModel

    @FocusState private var isFocused: Bool
    @State private var keyMonitor = ChatComposerKeyMonitor()

    private var isDraftBlank: Bool {
        chatVM.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            if chatVM.isSuggestionListVisible {
                ChatSuggestionList(chatVM: chatVM)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            inputBox

            ChatComposerHints(isListVisible: chatVM.isSuggestionListVisible)
        }
        .frame(maxWidth: ChatMetrics.columnWidth)
        .animation(.snappy(duration: 0.22), value: chatVM.isSuggestionListVisible)
        .background(ChatWindowReader { keyMonitor.window = $0 })
        .onAppear {
            keyMonitor.chatVM = chatVM
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
        .onChange(of: chatVM.focusRequest) {
            isFocused = true
        }
        // Focus set before the window is key does not take; claim it once the window is
        // key, unless something else in that window already has the keyboard.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            guard !isFocused, let window = note.object as? NSWindow, window === keyMonitor.window,
                  window.firstResponder == nil || window.firstResponder === window
            else { return }
            isFocused = true
        }
    }

    // MARK: - Input Box

    private var inputBox: some View {
        let shape = RoundedRectangle(cornerRadius: ChatMetrics.composerCorner, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            if let context = contextChip {
                context
            }

            TextField(chatVM.composerPlaceholder, text: $chatVM.draft, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isFocused)
                .padding(.horizontal, 2)
                .frame(minHeight: 20)

            HStack(spacing: 6) {
                ChatComposerSlashButton(help: "chat.composer.commands".localized) {
                    insertSlash()
                }

                recentProjectsMenu

                Spacer(minLength: 8)

                sendButton
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(shape)
        .onTapGesture { isFocused = true }
        .chatGlass(cornerRadius: ChatMetrics.composerCorner)
        .overlay(
            shape.strokeBorder(Color.daAccent.opacity(isFocused ? 0.45 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .animation(.easeOut(duration: 0.12), value: isFocused)
    }

    private var sendButton: some View {
        let isBusy = chatVM.isBusy
        let isEnabled = isBusy || !isDraftBlank
        return Button {
            if isBusy {
                chatVM.stop()
            } else {
                chatVM.submit()
                isFocused = true
            }
        } label: {
            ChatIcon(isBusy ? .stop : .arrowUp, size: isBusy ? 13 : 16, weight: 2)
                .foregroundStyle(isEnabled ? Color.white : Color.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isEnabled ? Color.daAccent : Color.primary.opacity(0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(ChatPressScaleButtonStyle())
        .disabled(!isEnabled)
        .help(isBusy ? "chat.composer.stop".localized : "chat.composer.send".localized)
        .accessibilityLabel(isBusy ? "chat.composer.stop".localized : "chat.composer.send".localized)
        .animation(.easeOut(duration: 0.12), value: isEnabled)
        .animation(.easeOut(duration: 0.12), value: isBusy)
    }

    private var recentProjectsMenu: some View {
        Menu {
            let projects = chatVM.recentProjects
            if projects.isEmpty {
                Text("chat.composer.noRecentProjects".localized)
            } else {
                Section("chat.suggest.recentProjects".localized) {
                    ForEach(projects) { project in
                        Button {
                            chatVM.selectProject(project)
                            isFocused = true
                        } label: {
                            Text(project.name)
                        }
                    }
                }
            }
        } label: {
            ChatIcon(.folder, size: 14.5)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        // A borderless menu draws its label in the accent color otherwise.
        .tint(Color.secondary)
        .fixedSize()
        .frame(width: 28, height: 28)
        .background(ChatHoverCircle())
        .help("chat.composer.recentProjects".localized)
        .accessibilityLabel("chat.composer.recentProjects".localized)
    }

    /// Opens the command list by starting the draft with a slash.
    private func insertSlash() {
        if isDraftBlank {
            chatVM.draft = "/"
        } else if !chatVM.draft.hasPrefix("/") {
            chatVM.draft = "/" + chatVM.draft
        }
        isFocused = true
    }

    // MARK: - Context Chip

    private var pendingProject: ProjectInfo? {
        guard let pending = chatVM.pendingInput else { return nil }
        let id: String
        switch pending {
        case .noteText(let projectID), .todoText(let projectID): id = projectID
        }
        if let active = chatVM.activeProject, active.id == id { return active }
        return chatVM.appViewModel.projects.first { $0.id == id } ?? chatVM.activeProject
    }

    private var contextChip: AnyView? {
        if let pending = chatVM.pendingInput {
            let tag: String
            let tint: Color
            switch pending {
            case .noteText:
                tag = "chat.composer.pendingNote".localized
                tint = Color(hex: ChatAction.addNote.tintHex)
            case .todoText:
                tag = "chat.composer.pendingTodo".localized
                tint = Color(hex: ChatAction.addTodo.tintHex)
            }
            return AnyView(
                ChatContextChip(project: pendingProject, tag: tag, tagTint: tint) {
                    chatVM.handleEscape()
                    isFocused = true
                }
            )
        }
        if let project = chatVM.activeProject {
            return AnyView(ChatContextChip(project: project, tag: nil, tagTint: .clear, onClear: nil))
        }
        return nil
    }
}

// MARK: - Context Chip

private struct ChatContextChip: View {
    let project: ProjectInfo?
    let tag: String?
    let tagTint: Color
    let onClear: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            if let project {
                ProjectFolderIcon(project: project, size: 16, isInteractive: false)
                Text(project.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.daPrimaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let tag {
                Text(tag)
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.horizontal, 6)
                    .frame(height: 16)
                    .background(Capsule().fill(tagTint.opacity(0.2)))
                    .foregroundStyle(tagTint)
            }
            if let onClear {
                Button(action: onClear) {
                    ChatIcon(.close, size: 10)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("chat.composer.clearContext".localized)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, onClear == nil ? 9 : 4)
        .frame(height: 24)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
    }
}

// MARK: - Buttons

private struct ChatComposerSlashButton: View {
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("/")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(ChatHoverCircle())
                .contentShape(Circle())
        }
        .buttonStyle(ChatPressScaleButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct ChatHoverCircle: View {
    @State private var isHovered = false

    var body: some View {
        Circle()
            .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

private struct ChatPressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Hints

private struct ChatComposerHints: View {
    let isListVisible: Bool

    var body: some View {
        // Drops hints from the end as the window narrows, then hides the row.
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
                (["↩"], "chat.hint.send".localized),
                (["esc"], "chat.hint.dismiss".localized),
            ]
        }
        return [
            (["↩"], "chat.hint.send".localized),
            (["⇧", "↩"], "chat.hint.newline".localized),
            (["/"], "chat.hint.commands".localized),
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

// MARK: - Keyboard

/// Reports the window the composer is placed in.
private struct ChatWindowReader: NSViewRepresentable {
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

/// Takes the composer's special keys before the text field does. A vertical `TextField`
/// ends editing on Return inside AppKit's field editor, so SwiftUI's key handlers cannot
/// tell Return from Shift-Return reliably. This sees the raw event instead.
@MainActor
final class ChatComposerKeyMonitor {
    weak var chatVM: ChatViewModel?
    /// The window the composer is in. Keys typed into a popover or sheet are left alone.
    weak var window: NSWindow?
    var isFocused = false
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

    /// Returns true when the key was used here and must not reach the text field.
    private func handle(_ event: NSEvent) -> Bool {
        guard isFocused, let chatVM,
              let window = event.window, window === self.window, window.isKeyWindow,
              let textView = window.firstResponder as? NSTextView
        else { return false }
        // Japanese, Korean and Chinese input: keys belong to the input method while composing.
        if textView.hasMarkedText() { return false }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let listVisible = chatVM.isSuggestionListVisible

        switch Int(event.keyCode) {
        case kVK_UpArrow, kVK_DownArrow:
            // An Escape-dismissed list comes back on an arrow; in multi-line text with no
            // list the arrows move the caret.
            let canReopen = !chatVM.suggestions.isEmpty && !chatVM.draft.contains("\n")
            guard listVisible || canReopen, flags.isEmpty else { return false }
            chatVM.moveSuggestion(by: event.keyCode == UInt16(kVK_UpArrow) ? -1 : 1)
            return true
        case kVK_Tab:
            guard flags.isEmpty else { return false }
            return chatVM.acceptSuggestion()
        case kVK_Escape:
            return chatVM.handleEscape()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if flags.contains(.shift) || flags.contains(.option) {
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            if flags.contains(.control) { return false }
            chatVM.submit()
            return true
        default:
            break
        }

        // Emacs-style list navigation, as in the quick search panel.
        if listVisible, flags == .control, let key = event.charactersIgnoringModifiers {
            if key == "n" { chatVM.moveSuggestion(by: 1); return true }
            if key == "p" { chatVM.moveSuggestion(by: -1); return true }
        }
        return false
    }
}
