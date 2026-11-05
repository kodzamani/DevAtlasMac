import AppKit

/// Keeps the app alive in the menu bar and shows it in the Dock only while it has a window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: nil)
        center.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing.canBecomeMain else { return }
        let hasOtherWindow = NSApp.windows.contains { $0 !== closing && $0.isVisible && $0.canBecomeMain }
        if !hasOtherWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// Catches a window that comes back without the menu bar, such as relaunching from Finder.
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window.canBecomeMain else { return }
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
    }
}
