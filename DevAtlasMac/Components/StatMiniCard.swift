import SwiftUI

struct StatMiniCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.daTertiaryText)

            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.daPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .daCardSurface(cornerRadius: 10)
    }
}
