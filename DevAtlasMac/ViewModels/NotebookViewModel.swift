import SwiftUI
import Observation
import AppKit
import MarkdownUI

@Observable
final class NotebookViewModel {
    // MARK: - State
    var notes: [NotebookNote] = [] {
        didSet {
            cleanFilters()
        }
    }
    var selectedProjectId: String?
    var selectedNote: NotebookNote?
    var searchText: String = ""
    var newTodoText: String = ""
    
    // MARK: - New Feature Filters
    var showArchived: Bool = false
    var filterTags: Set<String> = []
    var selectedFolder: String?
    var sortOption: NoteSortOption = .updatedDesc

    // MARK: - Services
    private let store = NotebookStore.shared

    // MARK: - Computed

    var availableProjects: [(id: String, name: String)] {
        var seen = Set<String>()
        var result: [(id: String, name: String)] = []
        for note in notes {
            if seen.insert(note.projectId).inserted {
                result.append((id: note.projectId, name: note.projectName))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var availableFolders: [String] {
        var seen = Set<String>()
        for note in notes {
            if let f = note.folder, !f.isEmpty {
                seen.insert(f)
            }
        }
        return Array(seen).sorted()
    }
    
    var allTags: [String] {
        var seen = Set<String>()
        for note in notes {
            if let tags = note.tags {
                for t in tags {
                    seen.insert(t)
                }
            }
        }
        return Array(seen).sorted()
    }
    
    private func cleanFilters() {
        let currentFolders = Set(notes.compactMap { $0.folder }.filter { !$0.isEmpty })
        if let f = selectedFolder, !currentFolders.contains(f) {
            selectedFolder = nil
        }
        
        let currentTags = Set(notes.compactMap { $0.tags }.flatMap { $0 })
        filterTags.formIntersection(currentTags)
    }

    // Search scope property that will be set from the parent view
    var searchScope: NotebookSearchScope = .allNotes
    
    var filteredNotes: [NotebookNote] {
        var result = notes

        // Archive Filter
        if !showArchived {
            result = result.filter { !($0.isArchived ?? false) }
        } else {
            result = result.filter { $0.isArchived == true }
        }

        if let projectId = selectedProjectId {
            result = result.filter { $0.projectId == projectId }
        }
        
        if let folder = selectedFolder {
            result = result.filter { $0.folder == folder }
        }
        
        if !filterTags.isEmpty {
            result = result.filter { note in
                guard let tags = note.tags else { return false }
                return !filterTags.isDisjoint(with: Set(tags))
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { note in
                switch searchScope {
                case .allNotes:
                    return note.title.lowercased().contains(query) ||
                    note.content.lowercased().contains(query) ||
                    note.projectName.lowercased().contains(query) ||
                    note.todos.contains { $0.text.lowercased().contains(query) }
                case .currentProject:
                    guard let projectId = selectedProjectId else { return false }
                    return note.projectId == projectId && (
                        note.title.lowercased().contains(query) ||
                        note.content.lowercased().contains(query) ||
                        note.todos.contains { $0.text.lowercased().contains(query) }
                    )
                case .contentOnly:
                    return note.content.lowercased().contains(query) ||
                    note.todos.contains { $0.text.lowercased().contains(query) }
                case .byTags:
                    guard let tags = note.tags else { return false }
                    return tags.contains { $0.lowercased().contains(query) }
                }
            }
        }

        // Pinned notes bubble to top, then sorted by option
        return result.sorted {
            let pin0 = $0.isPinned ?? false
            let pin1 = $1.isPinned ?? false
            if pin0 != pin1 { return pin0 }
            
            switch sortOption {
            case .updatedDesc:
                return $0.updatedAt > $1.updatedAt
            case .createdDesc:
                return $0.createdAt > $1.createdAt
            case .titleAsc:
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            case .titleDesc:
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
            }
        }
    }

    func noteCount(for projectId: String) -> Int {
        notes.filter { $0.projectId == projectId }.count
    }

    // MARK: - Data Loading

    func loadNotes() async {
        guard !Task.isCancelled else { return }
        let loaded = await store.loadNotes()
        await MainActor.run {
            self.notes = loaded
        }
    }

    // MARK: - CRUD

    func createNote(projectId: String, projectName: String) async {
        guard !Task.isCancelled else { return }
        let note = NotebookNote(
            projectId: projectId,
            projectName: projectName,
            title: "Untitled Note",
            content: "",
            todos: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        let updated = await store.addNote(note)
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.notes = updated
            self.selectedNote = note
        }
    }

    func updateNote(_ note: NotebookNote) async {
        guard !Task.isCancelled else { return }
        var updated = note
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.notes = allNotes
            if self.selectedNote?.id == updated.id {
                self.selectedNote = updated
            }
        }
    }

    func deleteNote(_ note: NotebookNote) async {
        guard !Task.isCancelled else { return }
        let updated = await store.deleteNote(id: note.id)
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.notes = updated
            if self.selectedNote?.id == note.id {
                self.selectedNote = nil
            }
        }
    }
    
    // MARK: - New Note Features (Clone, Archive, Pin, Tags)
    
    func duplicateNote(_ note: NotebookNote) async {
        let updated = await store.duplicateNote(id: note.id)
        await MainActor.run {
            self.notes = updated
        }
    }
    
    func toggleArchiveNote(_ note: NotebookNote) async {
        var updated = note
        updated.isArchived = !(updated.isArchived ?? false)
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            if self.selectedNote?.id == updated.id {
                self.selectedNote = updated
            }
        }
    }
    
    func togglePinNote(_ note: NotebookNote) async {
        var updated = note
        updated.isPinned = !(updated.isPinned ?? false)
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            if self.selectedNote?.id == updated.id {
                self.selectedNote = updated
            }
        }
    }
    
    func updateNoteVisuals(colorCode: String?, iconName: String?, theme: String?, folder: String?, tags: [String]?, for note: NotebookNote) async {
        var updated = note
        updated.colorCode = colorCode
        updated.iconName = iconName
        updated.theme = theme
        updated.folder = folder
        updated.tags = tags
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            if self.selectedNote?.id == updated.id {
                self.selectedNote = updated
            }
        }
    }
    
    // MARK: - Attachments
    
    @MainActor
    func showAttachmentPicker(for note: NotebookNote) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                Task {
                    await addAttachment(url: url, to: note)
                }
            }
        }
    }
    
    func addAttachment(url: URL, to note: NotebookNote) async {
        var updated = note
        let attachment = NoteAttachment(
            name: url.lastPathComponent
        )
        if updated.attachments == nil {
            updated.attachments = []
        }
        updated.attachments?.append(attachment)
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            if self.selectedNote?.id == updated.id {
                self.selectedNote = updated
            }
        }
    }
    
    func removeAttachment(id: String, from note: NotebookNote) async {
        var updated = note
        updated.attachments?.removeAll { $0.id == id }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            if self.selectedNote?.id == updated.id {
                self.selectedNote = updated
            }
        }
    }

    // MARK: - Todo Operations

    func addTodo(to note: NotebookNote) async {
        guard !newTodoText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var updated = note
        let todo = TodoItem(text: newTodoText.trimmingCharacters(in: .whitespaces))
        updated.todos.append(todo)
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
            self.newTodoText = ""
        }
    }

    func toggleTodo(_ todoId: String, in note: NotebookNote) async {
        var updated = note
        if let idx = updated.todos.firstIndex(where: { $0.id == todoId }) {
            let newVal = !updated.todos[idx].isCompleted
            updated.todos[idx].isCompleted = newVal
            updated.todos[idx].status = newVal ? .done : .todo
        }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
        }
    }

    func setTodoStatus(_ status: TodoStatus, for todoId: String, in note: NotebookNote) async {
        var updated = note
        if let idx = updated.todos.firstIndex(where: { $0.id == todoId }) {
            updated.todos[idx].status = status
            updated.todos[idx].isCompleted = (status == .done)
        }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
        }
    }

    func deleteTodo(_ todoId: String, in note: NotebookNote) async {
        var updated = note
        updated.todos.removeAll { $0.id == todoId }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
        }
    }
    
    // MARK: - Advanced Todo Properties
    
    func updateTodoDetails(priority: TodoPriority?, assignee: String?, tags: [String]?, for todoId: String, in note: NotebookNote) async {
        var updated = note
        if let idx = updated.todos.firstIndex(where: { $0.id == todoId }) {
            updated.todos[idx].priority = priority
            updated.todos[idx].assignee = assignee
            updated.todos[idx].tags = tags
        }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
        }
    }
    
    func addSubTask(_ subTaskText: String, to todoId: String, in note: NotebookNote) async {
        guard !subTaskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var updated = note
        if let idx = updated.todos.firstIndex(where: { $0.id == todoId }) {
            let st = TodoItem(text: subTaskText.trimmingCharacters(in: .whitespaces))
            if updated.todos[idx].subTasks == nil {
                updated.todos[idx].subTasks = []
            }
            updated.todos[idx].subTasks?.append(st)
        }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
        }
    }
    
    func toggleSubTask(_ subTaskId: String, in todoId: String, note: NotebookNote) async {
        var updated = note
        if let tIdx = updated.todos.firstIndex(where: { $0.id == todoId }),
           var subTasks = updated.todos[tIdx].subTasks,
           let stIdx = subTasks.firstIndex(where: { $0.id == subTaskId }) {
            subTasks[stIdx].isCompleted.toggle()
            updated.todos[tIdx].subTasks = subTasks
        }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
        }
    }
    
    func deleteSubTask(_ subTaskId: String, in todoId: String, note: NotebookNote) async {
        var updated = note
        if let tIdx = updated.todos.firstIndex(where: { $0.id == todoId }),
           var subTasks = updated.todos[tIdx].subTasks {
            subTasks.removeAll { $0.id == subTaskId }
            updated.todos[tIdx].subTasks = subTasks
        }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
        }
    }

    // MARK: - Auto-save helpers

    func saveTitle(_ title: String, for note: NotebookNote) async {
        guard !Task.isCancelled else { return }
        var updated = note
        updated.title = title
        await updateNote(updated)
    }

    func saveContent(_ content: String, for note: NotebookNote) async {
        guard !Task.isCancelled else { return }
        var updated = note
        updated.content = content
        
        let lines = content.components(separatedBy: .newlines)
        var completedLines = lines
        // Ignore the last line since it may still be actively typed
        if !completedLines.isEmpty {
            completedLines.removeLast()
        }
        
        var recognizedTodoTexts: Set<String> = []
        
        for line in completedLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var text = ""
            if trimmed.hasPrefix("- [ ] ") {
                text = String(trimmed.dropFirst(6))
            } else if trimmed.hasPrefix("- [x] ") {
                text = String(trimmed.dropFirst(6))
            } else if trimmed.hasPrefix("- ") {
                text = String(trimmed.dropFirst(2))
            } else {
                continue
            }
            
            let cleanText = text.trimmingCharacters(in: .whitespaces)
            if !cleanText.isEmpty {
                recognizedTodoTexts.insert(cleanText)
            }
        }
        
        // Add new auto-generated todos if they don't exist yet
        for text in recognizedTodoTexts {
            if !updated.todos.contains(where: { $0.text == text }) {
                var newTodo = TodoItem(text: text)
                newTodo.isAutoGenerated = true
                updated.todos.append(newTodo)
            }
        }
        
        // Remove auto-generated todos that are no longer in the notes
        updated.todos.removeAll { todo in
            if todo.isAutoGenerated == true {
                return !recognizedTodoTexts.contains(todo.text)
            }
            return false
        }
        
        await updateNote(updated)
    }

    func setDueDate(_ dueDate: Date?, todoId: String, in note: NotebookNote) async {
        var updated = note
        if let idx = updated.todos.firstIndex(where: { $0.id == todoId }) {
            updated.todos[idx].dueDate = dueDate
        }
        updated.updatedAt = Date()
        let allNotes = await store.updateNote(updated)
        await MainActor.run {
            self.notes = allNotes
            self.selectedNote = updated
        }
    }

    // MARK: - Export Methods
    
    @MainActor
    func exportNoteToMarkdown(_ note: NotebookNote) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.utf8PlainText] // or UTType.markdown
        panel.nameFieldStringValue = (note.title.isEmpty ? "Note" : note.title) + ".md"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try note.content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export Error: \(error)")
            }
        }
    }

    @MainActor
    func exportNoteToPDF(_ note: NotebookNote) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = note.title.isEmpty ? "Note" : note.title
        if panel.runModal() == .OK, let url = panel.url {
            let paperSize = CGSize(width: 595.2, height: 841.8) // A4
            let margin: CGFloat = 40.0
            let printableWidth = paperSize.width - (margin * 2)
            let printableHeight = paperSize.height - (margin * 2)
            
            let exportView = PDFExportView(noteContent: note.content)
                .frame(width: printableWidth)
            
            // To get the total height of the completely rendered Markdown
            let hostingView = NSHostingView(rootView: exportView)
            hostingView.frame = NSRect(x: 0, y: 0, width: printableWidth, height: 100000)
            hostingView.layout()
            
            let totalHeight = max(hostingView.fittingSize.height, printableHeight)
            let pageCount = Int(ceil(totalHeight / printableHeight))
            
            var box = CGRect(x: 0, y: 0, width: paperSize.width, height: paperSize.height)
            guard let pdfContext = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            
            for page in 0..<pageCount {
                pdfContext.beginPDFPage(nil)
                
                let yOffset = CGFloat(page) * printableHeight
                
                // Slice the continuous single view into an A4 page
                let sliceView = exportView
                    .frame(width: printableWidth, height: totalHeight, alignment: .top)
                    .offset(y: -yOffset)
                    .frame(width: printableWidth, height: printableHeight, alignment: .top)
                    .clipped()
                    .padding(.horizontal, margin)    // Add printable margins
                    .padding(.top, margin)           // Start from top margin
                    .padding(.bottom, paperSize.height - printableHeight - margin) // Fix the aspect ratio
                    .frame(width: paperSize.width, height: paperSize.height, alignment: .top)
                    .background(Color.white)
                
                let renderer = ImageRenderer(content: sliceView)
                renderer.render { size, renderContext in
                    renderContext(pdfContext)
                }
                
                pdfContext.endPDFPage()
            }
            pdfContext.closePDF()
        }
    }
    
    @MainActor
    func exportNoteToRTF(_ note: NotebookNote) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.rtf]
        panel.nameFieldStringValue = note.title.isEmpty ? "Note" : note.title
        if panel.runModal() == .OK, let url = panel.url {
            let attrString = NSAttributedString(string: note.content, attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ])
        }
    }
    
    @MainActor
    func exportNoteToHTML(_ note: NotebookNote) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = (note.title.isEmpty ? "Note" : note.title) + ".html"
        if panel.runModal() == .OK, let url = panel.url {
            let htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>\(note.title)</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; padding: 2rem; max-width: 800px; margin: 0 auto; }
                    pre { background: #f4f4f4; padding: 1rem; border-radius: 4px; overflow-x: auto; }
                    code { background: #f4f4f4; padding: 0.2rem 0.4rem; border-radius: 2px; }
                    blockquote { border-left: 4px solid #ddd; margin: 0; padding-left: 1rem; color: #666; }
                </style>
            </head>
            <body>
                <h1>\(note.title)</h1>
                <pre>\(note.content)</pre>
            </body>
            </html>
            """
            do {
                try htmlContent.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export Error: \(error)")
            }
        }
    }
    
    @MainActor
    func importMarkdownFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.utf8PlainText, .data] // UTType.markdown
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let filename = url.deletingPathExtension().lastPathComponent
                
                // Determine a project to attach to, or use a default one/currently selected
                let defaultProjectId = self.selectedProjectId ?? UUID().uuidString
                let defaultProjectName = self.availableProjects.first(where: { $0.id == defaultProjectId })?.name ?? "Imported Notes"
                
                let note = NotebookNote(
                    projectId: defaultProjectId,
                    projectName: defaultProjectName,
                    title: filename,
                    content: content,
                    todos: [],
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                Task {
                    let updated = await store.addNote(note)
                    self.notes = updated
                    self.selectedNote = note
                }
            } catch {
                print("Import Error: \(error)")
            }
        }
    }
}
