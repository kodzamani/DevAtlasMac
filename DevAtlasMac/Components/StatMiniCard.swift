import SwiftUI

/// One figure in a stats strip. The strip provides the surface.
struct StatMiniCard: View {
    let label: String
    /// Nil while the value is still loading.
    let value: String?
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.daTertiaryText)
                .lineLimit(1)

            if let value {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.daPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            } else {
                SkeletonBlock()
                    .frame(width: 64, height: 18)
                    .padding(.vertical, 3)
            }

            if let footnote {
                Text(footnote)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.daTertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// The hairline between two figures in a stats strip.
struct StatStripDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.daCardEdge)
            .frame(width: 1)
            .padding(.vertical, 12)
    }
}
