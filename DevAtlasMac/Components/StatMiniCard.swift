import SwiftUI

struct StatMiniCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.daSmallLabelSemiBold)
                .foregroundStyle(Color.daMutedText)

            Text(value)
                .font(.daBodySemiBold)
                .foregroundStyle(Color.daPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.daLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
