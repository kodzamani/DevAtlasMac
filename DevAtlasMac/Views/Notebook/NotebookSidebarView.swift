import SwiftUI

struct NotebookSidebarView: View {
    @Bindable var viewModel: AppViewModel
    @Bindable var notebookVM: NotebookViewModel
    @State private var detailProject: ProjectInfo?

    /// Projects deduplicated by name
    private var uniqueProjects: [ProjectInfo] {
        var seen = Set<String>()
        return viewModel.projects
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .filter { seen.insert($0.name).inserted }
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            searchField
            projectList
            Spacer()
            bottomSection
        }
        .frame(width: 180)
        .background(Color.daWhite)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.daBorder)
                .frame(width: 0.7)
        }
        .sheet(item: $detailProject) { project in
            ProjectDetailView(viewModel: viewModel, project: project)
                .frame(minWidth: 900, minHeight: 600)
        }
    }

    // MARK: - Section Header
    private var sectionHeader: some View {
        Text("notebook.allNotes".localized)
            .font(.daSmallLabelSemiBold)
            .foregroundStyle(Color.daMutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.init(top: 14, leading: 14, bottom: 6, trailing: 14))
    }

    // MARK: - Search
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9))
                .foregroundStyle(Color.daMutedText)
            ZStack(alignment: .leading) {
                if notebookVM.searchText.isEmpty {
                    Text("notebook.searchNotesPlaceholder".localized)
                        .font(.daSmallLabel)
                        .foregroundStyle(Color.daMutedText)
                }
                TextField("", text: $notebookVM.searchText)
                    .font(.daSmallLabel)
                    .foregroundStyle(Color.daPrimaryText)
                    .textFieldStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.daLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.daBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Project List
    private var projectList: some View {
        ScrollView {
            VStack(spacing: 1) {
                // "All Notes" item
                sidebarItem(
                    title: "notebook.allNotes".localized,
                    icon: "note.text",
                    count: notebookVM.notes.count,
                    isSelected: notebookVM.selectedProjectId == nil
                ) {
                    notebookVM.selectedProjectId = nil
                }

                // Per-project items
                ForEach(uniqueProjects, id: \.id) { project in
                    let count = notebookVM.noteCount(for: project.id)
                    if count > 0 || notebookVM.selectedProjectId == project.id {
                        sidebarItem(
                            title: project.name,
                            icon: "folder",
                            count: count,
                            isSelected: notebookVM.selectedProjectId == project.id
                        ) {
                            notebookVM.selectedProjectId = project.id
                        }
                        .onTapGesture(count: 2) {
                            detailProject = project
                        }
                    }
                }
                
                // Folders Section
                if !notebookVM.availableFolders.isEmpty {
                    Text("notebook.folders".localized)
                        .font(.daSmallLabelSemiBold)
                        .foregroundStyle(Color.daMutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                        .padding(.leading, 8)
                        .padding(.bottom, 4)
                    
                    ForEach(notebookVM.availableFolders, id: \.self) { folder in
                        sidebarItem(
                            title: folder,
                            icon: "folder.fill",
                            count: 0,
                            isSelected: notebookVM.selectedFolder == folder
                        ) {
                            if notebookVM.selectedFolder == folder {
                                notebookVM.selectedFolder = nil
                            } else {
                                notebookVM.selectedFolder = folder
                            }
                        }
                    }
                }
                
                // Tags Section
                if !notebookVM.allTags.isEmpty {
                    Text("notebook.tags".localized)
                        .font(.daSmallLabelSemiBold)
                        .foregroundStyle(Color.daMutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                        .padding(.leading, 8)
                        .padding(.bottom, 4)
                    
                    ForEach(notebookVM.allTags, id: \.self) { tag in
                        sidebarItem(
                            title: "#\(tag)",
                            icon: "tag.fill",
                            count: 0,
                            isSelected: notebookVM.filterTags.contains(tag)
                        ) {
                            if notebookVM.filterTags.contains(tag) {
                                notebookVM.filterTags.remove(tag)
                            } else {
                                notebookVM.filterTags.insert(tag)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Sidebar Item
    private func sidebarItem(title: String, icon: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.daAccent : Color.daSecondaryText)
                    .frame(width: 16)

                Text(title)
                    .font(.daBodyMedium)
                    .foregroundStyle(isSelected ? Color.daPrimaryText : Color.daSecondaryText)
                    .lineLimit(1)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? Color.daAccent : Color.daMutedText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(isSelected ? Color.daAccentLight : Color.daLightGray)
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.daAccentLight.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 10) {
            Menu {
                ForEach(uniqueProjects, id: \.id) { project in
                    Button(project.name) {
                        Task {
                            notebookVM.selectedProjectId = project.id
                            await notebookVM.createNote(projectId: project.id, projectName: project.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                    Text("notebook.newNote".localized)
                        .font(.daBodyMedium)
                }
                .foregroundStyle(Color.daAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.daAccentLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.daAccent.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            Button {
                notebookVM.importMarkdownFile()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11))
                    Text("notebook.importMd".localized)
                        .font(.daBodyMedium)
                }
                .foregroundStyle(Color.daSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.daLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.daBorder).frame(height: 1)
        }
    }
}
