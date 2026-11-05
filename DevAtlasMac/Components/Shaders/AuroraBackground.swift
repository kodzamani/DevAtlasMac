import SwiftUI

/// Neutral window surface with a faint, slowly drifting accent wash. Pauses when the window is inactive or Reduce Motion is on.
struct AuroraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.colorScheme) private var colorScheme

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 8.0, paused: reduceMotion || controlActiveState != .key)) { context in
            GeometryReader { proxy in
                Rectangle()
                    .colorEffect(
                        ShaderLibrary.daAurora(
                            .float2(proxy.size),
                            .float(context.date.timeIntervalSince(startDate)),
                            .color(Color.daAccent),
                            .float(colorScheme == .dark ? 1 : 0)
                        )
                    )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
