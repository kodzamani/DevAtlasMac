import SwiftUI

struct CompactQuickActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)

                Text(title)
                    .font(.daSmallLabel)
                    .foregroundStyle(Color.daPrimaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHovered ? Color.daLightGray.opacity(0.7) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
