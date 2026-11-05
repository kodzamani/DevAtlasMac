import SwiftUI

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
