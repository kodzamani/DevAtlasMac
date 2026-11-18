import SwiftUI

@available(macOS 14.0, *)
private struct RippleShading: ViewModifier {
    let origin: CGPoint
    let elapsed: TimeInterval
    let duration: TimeInterval

    func body(content: Content) -> some View {
        let origin = origin
        let elapsed = elapsed
        let isEnabled = elapsed > 0 && elapsed < duration
        let amplitude: Double = 2.5

        content.visualEffect { view, _ in
            view.layerEffect(
                ShaderLibrary.daRipple(
                    .float2(origin),
                    .float(elapsed),
                    .float(amplitude),
                    .float(14),
                    .float(9),
                    .float(380)
                ),
                maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                isEnabled: isEnabled
            )
        }
    }
}

extension View {
    /// Plays a short, subtle Metal ripple from `origin` whenever `trigger` changes.
    /// Only use on purely SwiftUI content: shaders can't sample AppKit-backed views.
    func daRipple<Trigger: Equatable>(origin: CGPoint, trigger: Trigger) -> some View {
        let duration: TimeInterval = 0.5
        return RippleHost(origin: origin, trigger: trigger, duration: duration) { self }
    }
}

/// Applies the ripple on macOS 14+; plain content before (Metal shaders and keyframes need 14).
private struct RippleHost<Trigger: Equatable, Content: View>: View {
    let origin: CGPoint
    let trigger: Trigger
    let duration: TimeInterval
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(macOS 14.0, *) {
            content().keyframeAnimator(initialValue: TimeInterval(0), trigger: trigger) { view, elapsed in
                view.modifier(RippleShading(origin: origin, elapsed: elapsed, duration: duration))
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(duration, duration: duration)
            }
        } else {
            content()
        }
    }
}
