import AppKit
import SwiftUI

/// Hosts a session's terminal view. The view itself belongs to the session, so switching tabs or
/// sessions only moves it in and out of this container and never restarts the process.
struct AgentTerminalView: NSViewRepresentable {
    let session: AgentSession
    let isDarkMode: Bool

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let terminal = session.terminalView
        terminal.applyTheme(dark: isDarkMode)
        container.layer?.backgroundColor = terminal.nativeBackgroundColor.cgColor
        guard container.subviews.first !== terminal else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        terminal.removeFromSuperview()
        terminal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            terminal.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
    }

    static func dismantleNSView(_ container: NSView, coordinator: ()) {
        // Detach without ending the process; the session may be shown again later.
        container.subviews.forEach { $0.removeFromSuperview() }
    }
}
