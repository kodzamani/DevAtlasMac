import SwiftUI
import AppKit

struct TrafficLightAligner: NSViewRepresentable {
    let barHeight: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = AlignerNSView()
        view.barHeight = barHeight
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? AlignerNSView {
            view.barHeight = barHeight
            view.alignButtons()
        }
    }
}

class AlignerNSView: NSView {
    var barHeight: CGFloat = 52
    private var customObserver: NSKeyValueObservation?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupObserver()
            alignButtons()
        }
    }

    private func setupObserver() {
        guard let window = self.window, 
              let closeButton = window.standardWindowButton(.closeButton) else { return }
        
        customObserver = closeButton.observe(\.frame, options: [.new]) { [weak self] _, _ in
            self?.alignButtons()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(alignButtons), name: NSWindow.didResizeNotification, object: window)
    }

    deinit {
        customObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc func alignButtons() {
        guard let window = self.window else { return }
        
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        
        guard let closeButton = window.standardWindowButton(.closeButton),
              let titlebarView = closeButton.superview else { return }
              
        let buttonHeight = closeButton.frame.height
        let verticalCenter = (barHeight - buttonHeight) / 2
        let targetY = titlebarView.frame.height - verticalCenter - buttonHeight
        
        if abs(closeButton.frame.origin.y - targetY) > 0.1 {
            for type in buttonTypes {
                if let button = window.standardWindowButton(type) {
                    button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: targetY))
                }
            }
        }
    }
}
