import SwiftUI
import AppKit

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DragView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
