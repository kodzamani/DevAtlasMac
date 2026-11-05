import SwiftUI

extension View {
    /// The app's flat card: a faint translucent fill and a hairline, so it stays part of the window surface.
    func daCardSurface(cornerRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return background(Color.daCard, in: shape)
            .overlay(shape.strokeBorder(Color.daCardEdge, lineWidth: 1).allowsHitTesting(false))
    }
}
