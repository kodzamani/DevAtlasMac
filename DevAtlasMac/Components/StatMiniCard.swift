import SwiftUI

/// One figure in a stats strip. The strip provides the surface.
struct StatMiniCard: View {
    let label: String
    let systemImage: String
    /// Nil while the value is still loading.
    let value: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.daTertiaryText)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.daTertiaryText)

                if let value {
                    Text(value)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}
