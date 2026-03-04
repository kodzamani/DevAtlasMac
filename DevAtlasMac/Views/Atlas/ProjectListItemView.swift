import SwiftUI

struct ProjectListItemView: View {
    let project: ProjectInfo
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            iconBox
                .padding(.trailing, 12)

            projectInfo
                .frame(minWidth: 180, alignment: .leading)

            tagsArea
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)

            Text(project.projectType)
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.daBorder, lineWidth: 1)
        )
        .shadow(color: isHovered ? .black.opacity(0.04) : .clear, radius: 4, y: 1)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onTap)
        .cursor(.pointingHand)
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

    private var tagsArea: some View {
        HStack(spacing: 4) {
            ForEach(project.tags.prefix(4), id: \.self) { tag in
                Text(tag)
                    .font(.daCardTag)
                    .foregroundStyle(Color.daSecondaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.daLightGray)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}
