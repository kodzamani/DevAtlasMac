import SwiftUI

/// A compact icon-and-title button for the action bar on the project page.
struct CompactQuickActionCard: View {
    let glyph: LineGlyph
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                LineGlyphView(glyph: glyph, isSelected: isHovered)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .lineLimit(1)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: 32)
            .background(Color.primary.opacity(isHovered ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
