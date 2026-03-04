import SwiftUI

struct ProjectCardView: View {
    let project: ProjectInfo
    let onTap: () -> Void
    let onOpenCode: () -> Void
    let onRevealInFinder: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            tagsRow
            footerRow
        }
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.daBorder, lineWidth: 1)
        )
        .shadow(color: isHovered ? .black.opacity(0.06) : .clear, radius: 8, y: 2)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onTap)
        .cursor(.pointingHand)
    }

    // MARK: - Header
    private var headerRow: some View {
        HStack(spacing: 10) {
            iconBox
            projectInfo
            Spacer()
            if project.isActive {
                Circle()
                    .fill(Color.daGreen)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.init(top: 12, leading: 12, bottom: 10, trailing: 12))
    }

    private var iconBox: some View {
        Group {
            if let assetName = project.iconAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.white)
            } else if let systemImage = project.iconSystemImage {
                Image(systemName: systemImage)
                    .font(.daCardIcon)
                    .foregroundStyle(.white)
            } else {
                Text(project.displayIconText)
                    .font(.daCardIcon)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 28, height: 28)
        .background(Color(hex: project.displayIconColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var projectInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.name)
                .font(.daBodySemiBold)
                .foregroundStyle(Color.daPrimaryText)
                .lineLimit(1)

            Text(project.path)
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Tags
    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(project.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.daCardTag)
                        .foregroundStyle(Color.daSecondaryText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.daLightGray)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
        .padding(.init(top: 0, leading: 12, bottom: 10, trailing: 12))
    }

    // MARK: - Footer
    private var footerRow: some View {
        HStack {
            HStack(spacing: 4) {
                actionButton(icon: "chevron.left.forwardslash.chevron.right", action: onOpenCode)
                actionButton(icon: "folder", action: onRevealInFinder)
            }
            Spacer()
            Text(project.projectType)
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.daLightGray).frame(height: 1)
        }
    }

    private func actionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.daTertiaryText)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
