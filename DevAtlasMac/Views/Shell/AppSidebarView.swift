import SwiftUI

/// Finder-style source list. Uses the native sidebar so it picks up the system's translucency.
struct AppSidebarView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        List(selection: $viewModel.sidebarSelection) {
            Section("nav.projects".localized) {
                categoryRow("sidebar.allProjects".localized, icon: "square.grid.2x2", category: "All", count: viewModel.allCount)
                categoryRow("sidebar.web".localized, icon: "globe", category: "Web", count: viewModel.webCount)
                categoryRow("sidebar.desktop".localized, icon: "desktopcomputer", category: "Desktop", count: viewModel.desktopCount)
                categoryRow("sidebar.mobile".localized, icon: "iphone", category: "Mobile", count: viewModel.mobileCount)
                categoryRow("sidebar.cloud".localized, icon: "cloud", category: "Cloud", count: viewModel.cloudCount)
            }

            Section("nav.workspace".localized) {
                tabRow("tab.stats".localized, icon: "chart.bar", tab: .stats)
                tabRow("tab.notebook".localized, icon: "note.text", tab: .notebook)
                tabRow("tab.aiPrompts".localized, icon: "brain.head.profile", tab: .aiPrompts)
                tabRow("tab.settings".localized, icon: "gearshape", tab: .settings)
            }

            if !viewModel.topTags.isEmpty {
                Section("finder.tags".localized) {
                    ForEach(viewModel.topTags, id: \.self) { tag in
                        Label {
                            Text(tag).lineLimit(1)
                        } icon: {
                            Circle()
                                .fill(Self.tagColor(for: tag))
                                .frame(width: 10, height: 10)
                        }
                        .tag(SidebarDestination.tag(tag))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func categoryRow(_ title: String, icon: String, category: String, count: Int) -> some View {
        Label(title, systemImage: icon)
            .badge(count)
            .tag(SidebarDestination.category(category))
    }

    private func tabRow(_ title: String, icon: String, tab: AppTab) -> some View {
        Label(title, systemImage: icon)
            .tag(SidebarDestination.tab(tab))
    }

    /// Finder's tag palette, assigned from the tag's characters so a tag keeps its color across launches.
    private static func tagColor(for tag: String) -> Color {
        let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]
        let seed = tag.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[seed % palette.count]
    }
}
