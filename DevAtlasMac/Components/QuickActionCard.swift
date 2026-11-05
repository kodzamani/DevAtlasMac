import SwiftUI

/// A button in the project page's action bar.
struct CompactQuickActionCard: View {
    enum Style {
        case primary
        case secondary
        case iconOnly
    }

    let glyph: LineGlyph
    let title: String
    var style: Style = .secondary
    let action: () -> Void

    @State private var isHovered = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    private var fill: Color {
        switch style {
        case .primary:
            return Color.daAccent.opacity(isHovered ? 0.86 : 1)
        case .secondary, .iconOnly:
            return Color.primary.opacity(isHovered ? 0.09 : 0.05)
        }
    }

    var body: some View {
        Button(action: action) {
            label
                .frame(height: 32)
                .background(fill, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .primary:
            HStack(spacing: 6) {
                LineGlyphView(glyph: glyph)
                    .environment(\.backgroundProminence, .increased)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.leading, 9)
            .padding(.trailing, 13)
        case .secondary:
            HStack(spacing: 6) {
                LineGlyphView(glyph: glyph, isSelected: isHovered)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .lineLimit(1)
            }
            .padding(.leading, 9)
            .padding(.trailing, 13)
        case .iconOnly:
            LineGlyphView(glyph: glyph, isSelected: isHovered)
                .frame(width: 32)
        }
    }
}
