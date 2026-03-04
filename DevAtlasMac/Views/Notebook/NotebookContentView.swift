import SwiftUI

struct NotebookContentView: View {
    @Bindable var notebookVM: NotebookViewModel
    @Bindable var viewModel: AppViewModel
    var body: some View {
        HStack(spacing: 0) {
            noteListPanel
            
            if let selectedNote = notebookVM.selectedNote {
                NoteEditorView(notebookVM: notebookVM, note: selectedNote)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.daOffWhite)
        .onChange(of: viewModel.notebookSearchScope) { _, newScope in
            notebookVM.searchScope = newScope
        }
        .onChange(of: viewModel.searchText) { _, newText in
            notebookVM.searchText = newText
        }
    }
    
    // MARK: - Note List Panel
    private var noteListPanel: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text(panelTitle)
                    .font(.daBodySemiBold)
                    .foregroundStyle(Color.daPrimaryText)
                
                Spacer()
                
                Menu {
                    Picker("notebook.sortBy".localized, selection: $notebookVM.sortOption) {
                        ForEach(NoteSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    Divider()
                    
                    if !notebookVM.availableFolders.isEmpty {
                        Picker("notebook.folder".localized, selection: $notebookVM.selectedFolder) {
                            Text("notebook.allFolders".localized).tag(String?.none)
                            ForEach(notebookVM.availableFolders, id: \.self) { folder in
                                Text(folder).tag(String?.some(folder))
                            }
                        }
                    }
                    
                    Toggle("notebook.showArchived".localized, isOn: $notebookVM.showArchived)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(notebookVM.selectedFolder != nil ? Color.daAccent : Color.daMutedText)
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                
                Text("\(notebookVM.filteredNotes.count) \(("notebook.notesCount".localized))")
                    .font(.daSmallLabel)
                    .foregroundStyle(Color.daMutedText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.daWhite)
            .overlay(alignment: .bottom) {
                Divider().foregroundStyle(Color.daBorder)
            }
            
            // Notes list
            if notebookVM.filteredNotes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.daMutedText)
                    Text("notebook.noNotesYet".localized)
                        .font(.daBody)
                        .foregroundStyle(Color.daMutedText)
                    
                    if let projectId = notebookVM.selectedProjectId,
                       let project = viewModel.projects.first(where: { $0.id == projectId }) {
                        Button {
                            Task {
                                await notebookVM.createNote(projectId: project.id, projectName: project.name)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                                Text("notebook.newNote".localized)
                                    .font(.daBodyMedium)
                            }
                            .foregroundStyle(Color.daAccent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .keyboardShortcut("n", modifiers: .command)
                    } else {
                        Text("notebook.createNoteFromSidebar".localized)
                            .font(.daSmallLabel)
                            .foregroundStyle(Color.daMutedText.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(notebookVM.filteredNotes) { note in
                            NoteListItemView(
                                note: note,
                                isSelected: notebookVM.selectedNote?.id == note.id,
                                showProjectTag: notebookVM.selectedProjectId == nil,
                                onTap: {
                                    notebookVM.selectedNote = note
                                },
                                onDelete: {
                                    Task { await notebookVM.deleteNote(note) }
                                },
                                onClone: {
                                    Task { await notebookVM.duplicateNote(note) }
                                },
                                onTogglePin: {
                                    Task { await notebookVM.togglePinNote(note) }
                                },
                                onToggleArchive: {
                                    Task { await notebookVM.toggleArchiveNote(note) }
                                }
                            )
                        }
                        
                        // New Note button right after the last note
                        if let projectId = notebookVM.selectedProjectId,
                           let project = viewModel.projects.first(where: { $0.id == projectId }) {
                            Button {
                                Task {
                                    await notebookVM.createNote(projectId: project.id, projectName: project.name)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 11))
                                    Text("notebook.newNote".localized)
                                        .font(.daBodyMedium)
                                }
                                .foregroundStyle(Color.daAccent)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("n", modifiers: .command)
                        }
                    }
                    .padding(10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: notebookVM.filteredNotes)
                }
            }
        }
        .frame(width: 260)
        .background(Color.daWhite)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.daBorder)
                .frame(width: 0.5)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 40))
                .foregroundStyle(Color.daMutedText.opacity(0.5))
            
            Text("notebook.selectNoteToEdit".localized)
                .font(.daSectionHeader)
                .foregroundStyle(Color.daTertiaryText)
            
            Text("notebook.createNewFromSidebar".localized)
                .font(.daBody)
                .foregroundStyle(Color.daMutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.daOffWhite)
    }
    
    // MARK: - Helpers
    private var panelTitle: String {
        if let projectId = notebookVM.selectedProjectId,
           let project = viewModel.projects.first(where: { $0.id == projectId }) {
            return project.name
        }
        return "notebook.allNotes".localized
    }
}
