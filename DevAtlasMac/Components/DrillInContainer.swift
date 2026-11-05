import SwiftUI

/// Shows `detail` in place of `base`, as a step deeper into the same page.
/// `base` stays alive underneath, so coming back restores its scroll position and state.
struct DrillInContainer<Base: View, Detail: View>: View {
    let isPresented: Bool
    @ViewBuilder var base: Base
    @ViewBuilder var detail: Detail

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var detailTransition: AnyTransition {
        reduceMotion ? .opacity : .offset(x: 44).combined(with: .opacity)
    }

    var body: some View {
        ZStack {
            base
                .offset(x: isPresented && !reduceMotion ? -28 : 0)
                .opacity(isPresented ? 0 : 1)
                .allowsHitTesting(!isPresented)
                .accessibilityHidden(isPresented)

            if isPresented {
                detail
                    .transition(detailTransition)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.92), value: isPresented)
    }
}
