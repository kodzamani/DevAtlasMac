import SwiftUI

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
        return keyframeAnimator(initialValue: TimeInterval(0), trigger: trigger) { view, elapsed in
            view.modifier(RippleShading(origin: origin, elapsed: elapsed, duration: duration))
        } keyframes: { _ in
            MoveKeyframe(0)
            LinearKeyframe(duration, duration: duration)
        }
    }
}
