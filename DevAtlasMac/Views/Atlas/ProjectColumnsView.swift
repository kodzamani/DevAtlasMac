import SwiftUI

/// Finder's column view: project kinds, the projects of that kind, then a preview.
struct ProjectColumnsView: View {
    @Bindable var viewModel: AppViewModel

    @State private var selectedKind: String?

    private var kinds: [(name: String, count: Int)] {
        Dictionary(grouping: viewModel.filteredProjects, by: \.projectType)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var activeKind: String? {
        if let selectedKind, kinds.contains(where: { $0.name == selectedKind }) { return selectedKind }
        if let highlighted = viewModel.highlightedProject { return highlighted.projectType }
        return kinds.first?.name
    }

    private var projectsOfKind: [ProjectInfo] {
        viewModel.filteredProjects
            .filter { $0.projectType == activeKind }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        HStack(spacing: 0) {
            kindColumn.frame(width: 210)
            Divider()
            projectColumn.frame(width: 260)
            Divider()
            ProjectPreviewPane(viewModel: viewModel, project: viewModel.highlightedProject)
                .frame(maxWidth: .infinity)
        }
    }

    private var kindColumn: some View {
        List(selection: Binding(get: { activeKind }, set: { selectedKind = $0 })) {
            ForEach(kinds, id: \.name) { kind in
                HStack(spacing: 7) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.daAccent)
                        .font(.system(size: 12))
                    Text(kind.name).lineLimit(1)
                    Spacer()
                    Text("\(kind.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .tag(kind.name)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var projectColumn: some View {
        List(selection: $viewModel.highlightedProjectID) {
            ForEach(projectsOfKind) { project in
                HStack(spacing: 7) {
                    ProjectFolderIcon(project: project, size: 20, isInteractive: false)
                    Text(project.name).lineLimit(1).truncationMode(.middle)
                }
                .tag(project.id)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: ProjectInfo.ID.self) { ids in
            if let id = ids.first, let project = projectsOfKind.first(where: { $0.id == id }) {
                ProjectContextMenu(viewModel: viewModel, project: project)
            }
        } primaryAction: { ids in
            if let id = ids.first, let project = projectsOfKind.first(where: { $0.id == id }) {
                viewModel.selectProject(project)
            }
        }
    }
}
