import SwiftUI

extension View {
    /// The app's flat card: a faint translucent fill and a hairline, so the Metal surface shows through.
    func daCardSurface(cornerRadius: CGFloat = 12) -> some View {
        background(Color.daCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.daBorder.opacity(0.8), lineWidth: 1)
            )
    }
}
