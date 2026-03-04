import SwiftUI

struct ProjectListView: View {
    @Bindable var viewModel: AppViewModel
    var onShowOnboarding: (() -> Void)? = nil

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.filteredProjects.isEmpty {
                emptyState
            } else {
                ScrollView {
                    if viewModel.isGridView {
                        gridView
                    } else {
                        listView
                    }
                }
                .background(Color.daOffWhite)
                .overlay(alignment: .bottomTrailing) {
                    footerView
                        .padding(16)
                }
            }
        }
    }

    // MARK: - Grid View
    private var gridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(viewModel.groupedFilteredProjects, id: \.0.id) { group, projects in
                Section(header: sectionHeader(for: group, count: projects.count)) {
                    ForEach(projects) { project in
                        ProjectCardView(
                            project: project,
                            onTap: { viewModel.selectProject(project) },
                            onOpenCode: {
                                if project.isAppleProject {
                                    viewModel.openInXcode(project)
                                } else {
                                    viewModel.openInVSCode(project)
                                }
                            },
                            onRevealInFinder: { viewModel.revealInFinder(project) }
                        )
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - List View
    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.groupedFilteredProjects, id: \.0.id) { group, projects in
                Section(header: sectionHeader(for: group, count: projects.count)) {
                    ForEach(projects) { project in
                        ProjectListItemView(
                            project: project,
                            onTap: { viewModel.selectProject(project) }
                        )
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Section Header
    private func sectionHeader(for group: ProjectTimelineGroup, count: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: group.iconSystemName)
                    .foregroundStyle(group.iconColor)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(group.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.daPrimaryText)
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.daLightBlue)
                    .foregroundStyle(Color.daBlue)
                    .clipShape(Capsule())
                
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
            
            Divider()
                .padding(.bottom, 8)
        }
    }

    // MARK: - Footer View
    private var footerView: some View {
        HStack(spacing: 8) {
            if viewModel.isCalculatingStats {
                ProgressView()
                    .controlSize(.small)
                Text("projects.calculatingStats".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
            } else {
                Group {
                    Text("\(viewModel.filteredProjects.count) " + "projects.footer.projects".localized)
                    Text("•")
                        .foregroundStyle(Color.daSecondaryText)
                    Text("\(viewModel.filteredTotalFiles.formatted()) " + "projects.footer.files".localized)
                    Text("•")
                        .foregroundStyle(Color.daSecondaryText)
                    Text("\(viewModel.filteredTotalLines.formatted()) " + "projects.footer.lines".localized)
                }
                .foregroundStyle(Color.daPrimaryText)
                
                #if DEBUG
                if let onShowOnboarding {
                    Divider()
                        .frame(height: 12)
                    
                    Button(action: onShowOnboarding) {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11, weight: .medium))
                            Text("sidebar.showTour".localized)
                        }
                    }
                    .buttonStyle(.plain)
                }
                #endif
            }
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.daMutedText)

            Text("projects.noProjectsFound".localized)
                .font(.daSectionTitle)
                .foregroundStyle(Color.daSecondaryText)

            Text("projects.tryScanning".localized)
                .font(.daBody)
                .foregroundStyle(Color.daTertiaryText)

            Button {
                Task { await viewModel.startScan() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.rays")
                    Text("projects.scanProjects".localized)
                }
                .font(.daBodyMedium)
                .foregroundStyle(Color.daBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.daLightBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.daOffWhite)
    }
}
