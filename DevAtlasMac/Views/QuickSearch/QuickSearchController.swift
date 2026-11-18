import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A borderless panel that takes typing without bringing DevAtlas to the front, like Spotlight.
final class QuickSearchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        // The card draws its own shadow; the window's would outline the empty area around it.
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// The strip, in window coordinates, that moves the panel when dragged: the search bar.
    var dragRegion: NSRect = .zero

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, dragRegion.contains(event.locationInWindow), moveIfDragged(from: event) {
            return
        }
        super.sendEvent(event)
    }

    /// Holds a press on the search bar until it is clear whether it is a click or a drag,
    /// since the field under it would otherwise take the drag as a text selection.
    /// Returns true if the press became a drag and moved the panel.
    private func moveIfDragged(from mouseDown: NSEvent) -> Bool {
        let start = NSEvent.mouseLocation
        while let next = nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp {
                // A plain click: put the release back so whatever is under it gets both halves.
                NSApp.postEvent(next, atStart: true)
                return false
            }
            let location = NSEvent.mouseLocation
            if hypot(location.x - start.x, location.y - start.y) > 3 {
                performDrag(with: mouseDown)
                return true
            }
        }
        return false
    }
}

/// Owns the Control-Space shortcut and the quick search panel it opens.
final class QuickSearchController: NSObject, NSWindowDelegate {
    static let shared = QuickSearchController()

    /// Opens the main window. Set by a SwiftUI view, which is the only place `openWindow` exists.
    var openMainWindow: (() -> Void)?

    private var viewModel: AppViewModel?
    private var model: QuickSearchModel?
    private var panel: QuickSearchPanel?
    private var hotKey: GlobalHotKey?
    private var keyMonitor: Any?

    /// Room around the card for its shadow, and for the list to grow into.
    private static let panelSize = NSSize(width: QuickSearchView.cardWidth + QuickSearchView.cardSideInset * 2, height: 600)

    /// Where the user last dragged the panel, as fractions of the screen so it carries across displays.
    private static let positionKey = "quickSearch.panelPosition"
    /// Where `show()` put the panel, to tell afterwards whether the user moved it.
    private var placedOrigin: NSPoint?

    private override init() {}

    func configure(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    /// Claims Control-Space. Called once the app has finished launching.
    func registerHotKey() {
        guard hotKey == nil else { return }
        let hotKey = GlobalHotKey(keyCode: kVK_Space, modifiers: controlKey) { [weak self] in
            self?.toggle()
        }
        if !hotKey.register() {
            NSLog("DevAtlas: Control-Space is taken by another app or by the input source shortcut.")
        }
        self.hotKey = hotKey
    }

    // MARK: - Showing

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        guard let viewModel else { return }
        let panel = panel ?? makePanel(viewModel: viewModel)
        // Follows the app's own light/dark choice, which can differ from the system's.
        panel.appearance = NSAppearance(named: viewModel.isDarkMode ? .darkAqua : .aqua)
        model?.reset()

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let origin = Self.origin(in: visible)
            panel.setFrame(NSRect(origin: origin, size: Self.panelSize), display: false)
            placedOrigin = origin
        }

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        focusSearchField(in: panel)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    /// SwiftUI's focus only takes once the panel is key, so it is asked again after showing,
    /// and AppKit is told directly in case SwiftUI still has not caught up.
    private func focusSearchField(in panel: NSPanel) {
        model?.requestFocus()
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let panel else { return }
            self?.model?.requestFocus()
            if !(panel.firstResponder is NSTextView), let field = Self.firstTextField(in: panel.contentView) {
                panel.makeFirstResponder(field)
            }
        }
    }

    private static func firstTextField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable { return field }
        for subview in view.subviews {
            if let field = firstTextField(in: subview) { return field }
        }
        return nil
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        rememberPosition(of: panel)
        panel.orderOut(nil)
    }

    // MARK: - Position

    /// The panel's origin on a screen: where the user last dragged it, or Spotlight's spot.
    private static func origin(in visible: NSRect) -> NSPoint {
        let size = panelSize
        var centerX = visible.midX
        // Upper third of the screen, where Spotlight sits.
        var top = visible.maxY - visible.height * 0.2
        if let saved = UserDefaults.standard.array(forKey: positionKey) as? [Double], saved.count == 2 {
            centerX = visible.minX + visible.width * saved[0]
            top = visible.maxY - visible.height * saved[1]
        }
        // Kept fully on screen, so the list always has room to grow downward.
        return NSPoint(
            x: min(max(centerX - size.width / 2, visible.minX), max(visible.maxX - size.width, visible.minX)),
            y: min(max(top - size.height, visible.minY), max(visible.maxY - size.height, visible.minY))
        )
    }

    private func rememberPosition(of panel: NSPanel) {
        let frame = panel.frame
        guard let placedOrigin, frame.origin != placedOrigin else { return }
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) } ?? panel.screen
        guard let visible = screen?.visibleFrame, visible.width > 0, visible.height > 0 else { return }
        UserDefaults.standard.set(
            [Double((frame.midX - visible.minX) / visible.width), Double((visible.maxY - frame.maxY) / visible.height)],
            forKey: Self.positionKey
        )
    }

    /// Clicking anywhere else closes the panel, as in Spotlight.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func makePanel(viewModel: AppViewModel) -> QuickSearchPanel {
        let model = QuickSearchModel(viewModel: viewModel)
        model.onFinish = { [weak self] in self?.hide() }
        model.onOpenInApp = { [weak self] project in
            viewModel.openProject(project)
            self?.showMainWindow()
        }

        let panel = QuickSearchPanel(contentRect: NSRect(origin: .zero, size: Self.panelSize))
        let hostingView = NSHostingView(rootView: QuickSearchView(model: model))
        if #available(macOS 13.0, *) { hostingView.sizingOptions = [] }
        panel.contentView = hostingView
        panel.delegate = self
        panel.dragRegion = NSRect(
            x: QuickSearchView.cardSideInset,
            y: Self.panelSize.height - QuickSearchView.cardTopInset - QuickSearchView.searchBarHeight,
            width: QuickSearchView.cardWidth,
            height: QuickSearchView.searchBarHeight
        )

        self.model = model
        self.panel = panel
        installKeyMonitor()
        return panel
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, event.window === panel, let model = self.model else { return event }
            return self.handle(event, model: model) ? nil : event
        }
    }

    /// Returns true when the key was used here and should not reach the search field.
    private func handle(_ event: NSEvent, model: QuickSearchModel) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)

        switch Int(event.keyCode) {
        case kVK_Escape:
            if !model.goBack() { hide() }
            return true
        case kVK_DownArrow:
            model.moveSelection(by: 1)
            return true
        case kVK_UpArrow:
            model.moveSelection(by: -1)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            command ? model.activateDefault() : model.activateSelection()
            return true
        case kVK_Tab:
            if flags.contains(.shift) {
                if model.isShowingActions { model.backToProjects() }
            } else if !model.isShowingActions {
                model.activateSelection()
            }
            return true
        case kVK_Delete:
            return model.deleteBackwardOnEmpty()
        default:
            break
        }

        if flags.contains(.control), event.charactersIgnoringModifiers == "n" {
            model.moveSelection(by: 1)
            return true
        }
        if flags.contains(.control), event.charactersIgnoringModifiers == "p" {
            model.moveSelection(by: -1)
            return true
        }
        if command, let characters = event.charactersIgnoringModifiers, let number = Int(characters), (1...9).contains(number) {
            return model.performAction(number: number)
        }
        if command, event.charactersIgnoringModifiers == "w" {
            hide()
            return true
        }
        return false
    }

    // MARK: - Main Window

    func showMainWindow() {
        // Back in the Dock first, or the window opens behind the frontmost app.
        NSApp.setActivationPolicy(.regular)
        if let openMainWindow {
            openMainWindow()
        } else if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is QuickSearchPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
