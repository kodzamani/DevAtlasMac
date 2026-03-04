import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            
            tabNavigation
            
            if viewModel.selectedTab == .atlas {
                sectionHeader
                navigationItems
            }

            Spacer()
            bottomSection
        }
        .frame(width: 190)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
        .background(Color.daWhite)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.daBorder)
                .frame(width: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTab)
    }

    // MARK: - Tab Navigation
    private var tabNavigation: some View {
        VStack(spacing: 1) {
            tabNavItem(title: "tab.atlas".localized, icon: "folder.fill", tab: .atlas)
            tabNavItem(title: "tab.stats".localized, icon: "chart.bar.fill", tab: .stats)
            tabNavItem(title: "tab.notebook".localized, icon: "note.text", tab: .notebook)
            tabNavItem(title: "tab.aiPrompts".localized, icon: "brain.head.profile", tab: .aiPrompts)
            tabNavItem(title: "tab.settings".localized, icon: "gearshape.fill", tab: .settings)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.daBorder).frame(height: 0.5)
        }
    }

    private func tabNavItem(title: String, icon: String, tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedTab = tab
            }
        } label: {
            // when the item is selected give it a bit more breathing room horizontally
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(viewModel.selectedTab == tab ? Color.daAccentDark : Color.daSecondaryText)
                    .frame(width: 16)
                Text(title)
                    .font(.daBodyMedium)
                    .foregroundStyle(viewModel.selectedTab == tab ? Color.daAccentDark : Color.daSecondaryText)
                Spacer()
            }
            // extra padding when active so the rounded background isn’t too tight
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.selectedTab == tab ? Color.daAccentLight : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Header
    private var sectionHeader: some View {
        Text("sidebar.explorer".localized)
            .font(.daSmallLabelSemiBold)
            .foregroundStyle(Color.daMutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.init(top: 14, leading: 14, bottom: 6, trailing: 14))
    }

    // MARK: - Navigation Items
    private var navigationItems: some View {
        VStack(spacing: 1) {
            SidebarItem(
                title: "sidebar.allProjects".localized,
                icon: { allProjectsIcon },
                count: viewModel.allCount,
                isSelected: viewModel.selectedCategory == "All",
                showBadge: true
            ) {
                viewModel.selectedCategory = "All"
            }

            SidebarItem(
                title: "sidebar.web".localized,
                icon: { AnyView(Image(systemName: "globe").font(.system(size: 12)).foregroundStyle(Color.daSecondaryText)) },
                count: viewModel.webCount,
                isSelected: viewModel.selectedCategory == "Web"
            ) {
                viewModel.selectedCategory = "Web"
            }

            SidebarItem(
                title: "sidebar.desktop".localized,
                icon: { AnyView(Image(systemName: "desktopcomputer").font(.system(size: 12)).foregroundStyle(Color.daSecondaryText)) },
                count: viewModel.desktopCount,
                isSelected: viewModel.selectedCategory == "Desktop"
            ) {
                viewModel.selectedCategory = "Desktop"
            }

            SidebarItem(
                title: "sidebar.mobile".localized,
                icon: { AnyView(Image(systemName: "iphone").font(.system(size: 12)).foregroundStyle(Color.daSecondaryText)) },
                count: viewModel.mobileCount,
                isSelected: viewModel.selectedCategory == "Mobile"
            ) {
                viewModel.selectedCategory = "Mobile"
            }

            SidebarItem(
                title: "sidebar.cloud".localized,
                icon: { AnyView(Image(systemName: "cloud").font(.system(size: 12)).foregroundStyle(Color.daSecondaryText)) },
                count: viewModel.cloudCount,
                isSelected: viewModel.selectedCategory == "Cloud"
            ) {
                viewModel.selectedCategory = "Cloud"
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - All Projects Icon
    private var allProjectsIcon: AnyView {
        AnyView(
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.daIconGridLight)
                        .frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.daIconGridDark)
                        .frame(width: 7, height: 7)
                }
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.daIconGridDark)
                        .frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.daIconGridLight)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 16, height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        )
    }

    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.startScan() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.rays")
                        .font(.system(size: 11))
                    Text("sidebar.scanProjects".localized)
                        .font(.daBodyMedium)
                }
                .foregroundStyle(Color.daTertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.daLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.daBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            HStack {
                Text("sidebar.darkMode".localized)
                    .font(.daBodyMedium)
                    .foregroundStyle(Color.daTertiaryText)
                Spacer()
                Toggle("", isOn: $viewModel.isDarkMode)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.daBorder).frame(height: 1)
        }
    }
}
