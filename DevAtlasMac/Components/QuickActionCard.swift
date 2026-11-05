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
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(isHovered ? Color.primary.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
