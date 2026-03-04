import SwiftUI

struct SidebarItem<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: () -> Icon
    let count: Int
    var isSelected: Bool = false
    var showBadge: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon()

                Text(title)
                    .font(.daBodyMedium)
                    .foregroundStyle(isSelected ? Color.daAccentDark : Color.daSecondaryText)

                Spacer()

                if showBadge && isSelected {
                    Text("\(count)")
                        .font(.daSmallLabel)
                        .foregroundStyle(Color.daAccentDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.daAccentVeryLight)
                        .clipShape(Capsule())
                } else {
                    Text("\(count)")
                        .font(.daFileExtension)
                        .foregroundStyle(Color.daMutedText)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.daAccentLight : (isHovered ? Color.daLightGray.opacity(0.5) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
