import SwiftUI

/// Finder's list view: sortable columns backed by a native table.
struct ProjectTableView: View {
    @Bindable var viewModel: AppViewModel

    @State private var sortOrder = [KeyPathComparator(\ProjectInfo.lastModified, order: .reverse)]

    private var rows: [ProjectInfo] {
        viewModel.filteredProjects.sorted(using: sortOrder)
    }

    var body: some View {
        Table(rows, selection: $viewModel.highlightedProjectID, sortOrder: $sortOrder) {
            TableColumn("finder.name".localized, value: \.name) { project in
                HStack(spacing: 7) {
                    ProjectFolderIcon(project: project, size: 20, isInteractive: false)
                    Text(project.name).lineLimit(1)
                }
            }
            .width(min: 180, ideal: 280)

            TableColumn("finder.dateModified".localized, value: \.lastModified) { project in
                Text(project.lastModified.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 170)

            TableColumn("finder.kind".localized, value: \.projectType) { project in
                Text(project.projectType).foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 110)

            TableColumn("finder.branch".localized) { project in
                Text(project.gitBranch ?? "—").foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 70, ideal: 110)

            TableColumn("finder.tags".localized) { project in
                Text(project.tags.joined(separator: ", ")).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: ProjectInfo.ID.self) { ids in
            if let project = project(from: ids) {
                ProjectContextMenu(viewModel: viewModel, project: project)
            }
        } primaryAction: { ids in
            if let project = project(from: ids) {
                viewModel.selectProject(project)
            }
        }
    }

    private func project(from ids: Set<ProjectInfo.ID>) -> ProjectInfo? {
        guard let id = ids.first else { return nil }
        return viewModel.filteredProjects.first { $0.id == id }
    }
}
