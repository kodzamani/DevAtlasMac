import SwiftUI

/// A line glyph on a soft accent tile.
struct OnboardingGlyphTile: View {
    let glyph: LineGlyph

    var body: some View {
        LineGlyphView(glyph: glyph, isSelected: true)
            .frame(width: 34, height: 34)
            .background(Color.daAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Tile, title and description, used for the rows and cards of the onboarding pages.
struct OnboardingFeatureRow: View {
    let glyph: LineGlyph
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            OnboardingGlyphTile(glyph: glyph)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
