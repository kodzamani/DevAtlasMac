import SwiftUI
import AppKit

struct TopNavigationBar: View {
    @Bindable var viewModel: AppViewModel
    @Bindable var notebookVM: NotebookViewModel
    @Bindable var statsVM: StatsViewModel
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            logoArea
            Spacer()

            if viewModel.selectedTab == .atlas {
                breadcrumb
                viewToggle
                    .padding(.leading, 12)
                    .padding(.trailing, 18)
            } else if viewModel.selectedTab == .notebook {
                themeToggle
                    .padding(.trailing, 18)
            } else if viewModel.selectedTab == .stats {
                statsControls
                    .padding(.trailing, 18)
            }
        }
        .overlay {
            searchBar
        }
        .frame(height: 52)
        .background(WindowDragArea())
        .background(TrafficLightAligner(barHeight: 52))
        .background(Color.daWhite)
        .overlay(alignment: .bottom) {
            Divider().foregroundStyle(Color.daBorder)
        }
    }

    // MARK: - Logo Area
    private var logoArea: some View {
        HStack(spacing: 3) {
            Image("logo_brand")
                .resizable()
                .frame(width: 35, height: 35)
                .padding(.trailing, 5)
            
            Text("nav.devAtlas".localized)
                .font(.daSectionHeaderSemiBold)
                .fontDesign(.rounded)
                .foregroundStyle(Color.daPrimaryText)
        
            Text("nav.workspace".localized)
                .font(.daSectionHeaderLight)
                .fontDesign(.rounded)
                .foregroundStyle(Color.daPrimaryText)
        }
        .padding(.leading, 78)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(Color.daTertiaryText.opacity(0.6))

            ZStack(alignment: .leading) {
                if viewModel.searchText.isEmpty {
                    Text(viewModel.selectedTab == .notebook ? "search.notes".localized : "search.projects".localized)
                        .font(.daBody)
                        .foregroundStyle(Color.daMutedText)
                }
                TextField("", text: $viewModel.searchText)
                    .font(.daBody)
                    .foregroundStyle(Color.daPrimaryText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
            }
            
            // Add search scope selector for notebook view
            if viewModel.selectedTab == .notebook {
                Menu {
                    Button("notebook.allNotes".localized) { viewModel.notebookSearchScope = .allNotes }
                    Button("notebook.currentProject".localized) { viewModel.notebookSearchScope = .currentProject }
                    Button("notebook.withinContent".localized) { viewModel.notebookSearchScope = .contentOnly }
                    Button("notebook.byCategoryTags".localized) { viewModel.notebookSearchScope = .byTags }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.notebookSearchScope.displayText)
                            .font(.daSmallLabel)
                            .foregroundStyle(Color.daSecondaryText)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.daMutedText)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.daVeryLightGray)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(width: viewModel.selectedTab == .notebook ? 450 : 350)
        .background(Color.daLightGray)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.daBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - Breadcrumb
    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Text("nav.projects".localized)
                .font(.daSectionHeaderSemiBold)
                .foregroundStyle(Color.daPrimaryText)

            Text("/")
                .font(.daSectionHeader)
                .foregroundStyle(Color.daSeparator)

            Text(viewModel.selectedCategory == "All" ? "sidebar.allProjects".localized : viewModel.selectedCategory)
                .font(.daSectionHeader)
                .foregroundStyle(Color.daTertiaryText)

            Text("/")
                .font(.daSectionHeader)
                .foregroundStyle(Color.daSeparator)

            Text("\(viewModel.filteredProjects.count) " + "common.items".localized)
                .font(.daSectionHeader)
                .foregroundStyle(Color.daTertiaryText)
        }
    }

    // MARK: - View Toggle
    private var viewToggle: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.isGridView = true
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14))
                    .foregroundStyle(viewModel.isGridView ? Color.daSecondaryText : Color.daMutedText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(viewModel.isGridView ? Color.daBorder : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.isGridView = false
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14))
                    .foregroundStyle(!viewModel.isGridView ? Color.daSecondaryText : Color.daMutedText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(!viewModel.isGridView ? Color.daBorder : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Theme Toggle (Notebook)
    private var themeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.isDarkMode.toggle()
            }
        } label: {
            Image(systemName: viewModel.isDarkMode ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.daSecondaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.daBorder.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Controls (Export & Date Filter)
    private var statsControls: some View {
        HStack(spacing: 16) {
            // Export Button
            Menu {
                Button("notebook.exportAsCsv".localized) {
                    statsVM.exportAsCSV()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10))
                    Text("nav.export".localized)
                        .font(.daBodyMedium)
                }
                .foregroundStyle(Color.daPrimaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.daOffWhite)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Date Range Picker
            Menu {
                ForEach(DateRangeFilter.allCases) { range in
                    Button {
                        statsVM.dateRange = range
                    } label: {
                        HStack {
                            Text(range.rawValue)
                            Spacer()
                            if statsVM.dateRange == range {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(statsVM.dateRange.rawValue)
                        .font(.daBodyMedium)
                        .foregroundStyle(Color.daPrimaryText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.daMutedText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.daOffWhite)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
    }
}
