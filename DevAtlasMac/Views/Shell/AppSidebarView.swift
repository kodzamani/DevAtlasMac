import SwiftUI

/// Finder-style source list. Rows draw their own selection so it stays a neutral highlight with an
/// accent icon, instead of the system's filled selection color when the list has keyboard focus.
struct AppSidebarView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        List {
            Section("nav.projects".localized) {
                categoryRow("sidebar.allProjects".localized, icon: .folder, category: "All", count: viewModel.allCount)
                categoryRow("sidebar.web".localized, icon: .globe, category: "Web", count: viewModel.webCount)
                categoryRow("sidebar.desktop".localized, icon: .desktop, category: "Desktop", count: viewModel.desktopCount)
                categoryRow("sidebar.mobile".localized, icon: .phone, category: "Mobile", count: viewModel.mobileCount)
                categoryRow("sidebar.cloud".localized, icon: .cloud, category: "Cloud", count: viewModel.cloudCount)
            }

            Section("nav.workspace".localized) {
                tabRow("tab.stats".localized, icon: .bars, tab: .stats)
                tabRow("tab.notebook".localized, icon: .notebook, tab: .notebook)
                tabRow("tab.aiPrompts".localized, icon: .sparkle, tab: .aiPrompts)
                tabRow("tab.settings".localized, icon: .sliders, tab: .settings)
            }

            if !viewModel.topTags.isEmpty {
                Section("finder.tags".localized) {
                    ForEach(viewModel.topTags, id: \.self) { tag in
                        row(tag, destination: .tag(tag)) {
                            Circle()
                                .fill(Self.tagColor(for: tag))
                                .frame(width: 9, height: 9)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func categoryRow(_ title: String, icon: LineGlyph, category: String, count: Int) -> some View {
        let destination = SidebarDestination.category(category)
        return row(title, count: count, destination: destination) {
            LineGlyphView(glyph: icon, isSelected: viewModel.sidebarSelection == destination)
        }
    }

    private func tabRow(_ title: String, icon: LineGlyph, tab: AppTab) -> some View {
        let destination = SidebarDestination.tab(tab)
        return row(title, destination: destination) {
            LineGlyphView(glyph: icon, isSelected: viewModel.sidebarSelection == destination)
        }
    }

    private func row<Icon: View>(
        _ title: String,
        count: Int? = nil,
        destination: SidebarDestination,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        SidebarRow(
            title: title,
            count: count,
            isSelected: viewModel.sidebarSelection == destination,
            icon: icon(),
            action: { viewModel.sidebarSelection = destination }
        )
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        .listRowSeparator(.hidden)
    }

    /// Finder's tag palette, assigned from the tag's characters so a tag keeps its color across launches.
    private static func tagColor(for tag: String) -> Color {
        let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]
        let seed = tag.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[seed % palette.count]
    }
}

private struct SidebarRow<Icon: View>: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let icon: Icon
    let action: () -> Void

    @State private var isHovered = false

    private var highlight: Color {
        if isSelected { return Color.primary.opacity(0.09) }
        return isHovered ? Color.primary.opacity(0.04) : Color.clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon.frame(width: 18, height: 18)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.daPrimaryText : Color.daSecondaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Color.daMutedText)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(highlight, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
