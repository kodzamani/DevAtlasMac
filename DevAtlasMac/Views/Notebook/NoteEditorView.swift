import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @Bindable var notebookVM: NotebookViewModel
    let note: NotebookNote
    
    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    @State private var isEditing: Bool = true
    @State private var isLoadingNote: Bool = false
    @State private var saveTask: Task<Void, Never>?
    @State private var dueDateTodoId: String?
    @State private var settingsTodoId: String?
    @State private var newSubTaskText: [String: String] = [:]
    @State private var isNotesFocused: Bool = false
    @State private var hoveredTodoId: String?
    @State private var addButtonPressed: Bool = false
    @State private var showSettingsPopover: Bool = false
    @State private var showSlashCommands: Bool = false
    @AppStorage("notebookTodoViewMode") private var isGridView: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider().foregroundStyle(Color.daBorder)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    notesSection
                    todoSection
                }
                .padding(24)
            }
            
            editorFooter
        }
        .background(Color.daOffWhite)
        .onAppear {
            editingTitle = note.title
            editingContent = note.content
        }
        .onDisappear {
            saveTask?.cancel()
        }
        .onChange(of: note.id) { _, _ in
            isLoadingNote = true
            editingTitle = note.title
            editingContent = note.content
            isEditing = true
            isLoadingNote = false
        }
    }
    
    // MARK: - Header
    private var editorHeader: some View {
        HStack(spacing: 10) {
            if let iconName = note.iconName, iconName != "none" {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(headerIconColor)
            }
            
            TextField("editor.noteTitle".localized, text: $editingTitle)
                .font(.daSectionTitle)
                .foregroundStyle(Color.daPrimaryText)
                .textFieldStyle(.plain)
                .onChange(of: editingTitle) { _, newVal in
                    guard !isLoadingNote, newVal != note.title else { return }
                    debounceSave {
                        await notebookVM.saveTitle(newVal, for: note)
                    }
                }
            
            // Settings Menu
            Button {
                showSettingsPopover.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daAccent)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.daLightBlue))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
                NoteSettingsView(notebookVM: notebookVM, note: note)
            }
            
            
            
            // Attachments
            Button {
                notebookVM.showAttachmentPicker(for: note)
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daAccent)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.daLightBlue))
            }
            .buttonStyle(.plain)
            
            // Export Menu
            Menu {
                Button("notebook.exportAsMarkdown".localized) { notebookVM.exportNoteToMarkdown(note) }
                Button("notebook.exportAsHtml".localized) { notebookVM.exportNoteToHTML(note) }
                Button("notebook.exportAsPdf".localized) { notebookVM.exportNoteToPDF(note) }
                Button("notebook.exportAsWord".localized) { notebookVM.exportNoteToRTF(note) }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.daAccent)
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.daLightBlue)
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .menuIndicator(.hidden)
            
            // Edit / Preview toggle
            HStack(spacing: 2) {
                Button {
                    isEditing = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 10))
                        Text("editor.edit".localized)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(isEditing ? Color.daAccent : Color.daMutedText)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isEditing ? Color.daWhite : Color.clear)
                            .shadow(color: isEditing ? Color.black.opacity(0.04) : Color.clear, radius: 1, y: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    isEditing = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 10))
                        Text("editor.preview".localized)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(!isEditing ? Color.daAccent : Color.daMutedText)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(!isEditing ? Color.daWhite : Color.clear)
                            .shadow(color: !isEditing ? Color.black.opacity(0.04) : Color.clear, radius: 1, y: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(Color.daLightGray)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text(note.projectName)
                .font(.daSmallLabelSemiBold)
                .foregroundStyle(Color.daAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.daLightBlue)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.daWhite)
    }
    
    // MARK: - Notes Section (Premium Card)
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with accent bar
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.daAccent, Color.daAccent.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 16)
                
                Image(systemName: "pencil.line")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daAccent)
                
                Text("editor.notes".localized)
                    .font(.daBodySemiBold)
                    .foregroundStyle(Color.daPrimaryText)
                
                Spacer()
                
                if !editingContent.isEmpty {
                    Text("\(editingContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count) " + "editor.words".localized)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.daMutedText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.daLightGray)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider().foregroundStyle(Color.daBorder.opacity(0.5))
            
            if let attachments = note.attachments, !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            HStack(spacing: 6) {
                                Image(systemName: "doc")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.daAccent)
                                Text(attachment.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.daSecondaryText)
                                Button {
                                    Task { await notebookVM.removeAttachment(id: attachment.id, from: note) }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.daMutedText)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.daVeryLightGray)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            
            // Editor area
            if isEditing {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $editingContent)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.daPrimaryText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                        .padding(14)
                        .onReceive(NotificationCenter.default.publisher(for: NSTextView.didBeginEditingNotification)) { _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isNotesFocused = true
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSTextView.didEndEditingNotification)) { _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isNotesFocused = false
                            }
                        }
                        .onChange(of: editingContent) { _, newVal in
                            guard !isLoadingNote, newVal != note.content else { return }
                            
                            // Slash command detection
                            if newVal.hasSuffix("/") || newVal.hasSuffix("\n/") || newVal.hasSuffix(" /") {
                                showSlashCommands = true
                            } else if showSlashCommands && !newVal.contains("/") {
                                showSlashCommands = false
                            }
                            
                            debounceSave {
                                await notebookVM.saveContent(newVal, for: note)
                            }
                        }
                    
                    // Placeholder
                    if editingContent.isEmpty {
                        Text("editor.startWriting".localized)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color.daMutedText.opacity(0.6))
                            .padding(14)
                            .padding(.top, 0)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    // Slash Command Overlay
                    if showSlashCommands {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("editor.slashCommands".localized)
                                .font(.daSmallLabelSemiBold)
                                .foregroundStyle(Color.daSecondaryText)
                                .padding(.horizontal, 8)
                                .padding(.top, 6)
                            
                            Divider().foregroundStyle(Color.daBorder)
                            
                            slashCommandItem(title: "editor.heading1".localized, icon: "textformat.size", insertValue: "# ")
                            slashCommandItem(title: "editor.heading2".localized, icon: "textformat.size.smaller", insertValue: "## ")
                            slashCommandItem(title: "editor.heading3".localized, icon: "textformat.size.smaller", insertValue: "### ")
                            slashCommandItem(title: "editor.todoList".localized, icon: "checklist", insertValue: "- [ ] ")
                            slashCommandItem(title: "editor.bulletList".localized, icon: "list.bullet", insertValue: "- ")
                            slashCommandItem(title: "editor.codeBlock".localized, icon: "curlybraces", insertValue: "```\n\n```")
                        }
                        .frame(width: 200)
                        .background(Color.daWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.daBorder, lineWidth: 1)
                        )
                        .padding(10)
                        .offset(y: -20)
                    }
                }
            } else {
                markdownPreview
                    .padding(14)
            }
        }
        .background(
            ZStack {
                Color.daWhite
                editorThemeBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isNotesFocused ? Color.daAccent.opacity(0.5) : Color.daBorder,
                    lineWidth: isNotesFocused ? 1.5 : 1
                )
        )
        .shadow(
            color: isNotesFocused ? Color.daAccent.opacity(0.08) : Color.black.opacity(0.03),
            radius: isNotesFocused ? 8 : 4,
            y: isNotesFocused ? 2 : 1
        )
    }
    
    // MARK: - Markdown Preview
    private var markdownPreview: some View {
        Group {
            if editingContent.isEmpty {
                Text("editor.noContentYet".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                    .italic()
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            } else {
                CustomMarkdownView(content: editingContent)
            }
        }
    }
    
    // MARK: - Todo Section (Premium Card)
    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with accent bar + progress
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.daEmerald, Color.daGreen.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 16)
                
                Image(systemName: "checklist")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daEmerald)
                
                Text("editor.todos".localized)
                    .font(.daBodySemiBold)
                    .foregroundStyle(Color.daPrimaryText)
                
                if !note.todos.isEmpty {
                    HStack(spacing: 0) {
                        Button {
                            isGridView = false
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 11, weight: !isGridView ? .bold : .medium))
                                .foregroundStyle(!isGridView ? Color.daAccent : Color.daMutedText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(!isGridView ? Color.daLightBlue.opacity(0.5) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            isGridView = true
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 11, weight: isGridView ? .bold : .medium))
                                .foregroundStyle(isGridView ? Color.daAccent : Color.daMutedText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isGridView ? Color.daLightBlue.opacity(0.5) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.daLightGray)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.leading, 8)
                }

                Spacer()
                
                if !note.todos.isEmpty {
                    premiumProgressBadge
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider().foregroundStyle(Color.daBorder.opacity(0.5))
            
            // Add Todo Input
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.daAccent.opacity(0.15), Color.daAccent.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.daAccent)
                    }
                    
                    TextField("editor.addTodoPlaceholder".localized, text: $notebookVM.newTodoText)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.daPrimaryText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task { await notebookVM.addTodo(to: note) }
                        }
                    
                    if !notebookVM.newTodoText.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                addButtonPressed = true
                            }
                            Task {
                                await notebookVM.addTodo(to: note)
                                addButtonPressed = false
                            }
                        } label: {
                            Text("editor.add".localized)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    LinearGradient(
                                        colors: [Color.daAccent, Color.daDarkBlue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: Color.daAccent.opacity(0.25), radius: 4, y: 2)
                                .scaleEffect(addButtonPressed ? 0.92 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            
            // Todo List
            if !note.todos.isEmpty {
                Divider().foregroundStyle(Color.daBorder.opacity(0.3)).padding(.horizontal, 12)
                
                if isGridView {
                    kanbanGrid()
                } else {
                    // Active todos
                    let activeTodos = note.todos.filter { !$0.isCompleted }
                    let completedTodos = note.todos.filter { $0.isCompleted }
                    
                    VStack(spacing: 1) {
                        ForEach(activeTodos) { todo in
                            todoRow(todo)
                        }
                        
                        // Completed section
                        if !completedTodos.isEmpty {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color.daBorder.opacity(0.5))
                                    .frame(height: 0.5)
                                Text("editor.completedCount".localized(completedTodos.count))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.daMutedText)
                                    .fixedSize()
                                Rectangle()
                                    .fill(Color.daBorder.opacity(0.5))
                                    .frame(height: 0.5)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            
                            ForEach(completedTodos) { todo in
                                todoRow(todo)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.daBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
    }
    
    // MARK: - Premium Progress Badge
    private var premiumProgressBadge: some View {
        let done = note.todos.filter(\.isCompleted).count
        let total = note.todos.count
        let progress = total > 0 ? Double(done) / Double(total) : 0
        let isComplete = done == total
        
        return HStack(spacing: 8) {
            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.daBorder.opacity(0.3), lineWidth: 2)
                    .frame(width: 18, height: 18)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isComplete ?
                        LinearGradient(colors: [Color.daGreen, Color.daEmerald], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.daAccent, Color.daDarkBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-90))
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.daGreen)
                }
            }
            
            Text("\(done)/\(total)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isComplete ? Color.daGreen : Color.daTertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(isComplete ? Color.daLightGreen.opacity(0.5) : Color.daLightGray)
        )
        .animation(.easeInOut(duration: 0.3), value: done)
    }
    
    // MARK: - Kanban Views
    private func kanbanGrid() -> some View {
        HStack(alignment: .top, spacing: 12) {
            kanbanColumn(title: TodoStatus.todo.title, status: .todo, color: Color.daAccent)
            kanbanColumn(title: TodoStatus.inProgress.title, status: .inProgress, color: Color.daOrange)
            kanbanColumn(title: TodoStatus.done.title, status: .done, color: Color.daGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 250)
    }
    
    private func kanbanColumn(title: String, status: TodoStatus, color: Color) -> some View {
        let items = note.todos.filter { $0.currentStatus == status }.sorted { $0.createdAt > $1.createdAt }
        
        return VStack(spacing: 8) {
            // Column Header
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.daMutedText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.daLightGray)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 4)
            
            // Cards
            VStack(spacing: 8) {
                ForEach(items) { item in
                    kanbanCard(item, columnColor: color)
                }
                
                // Drop Target Area
                Spacer()
                    .frame(minHeight: 40)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(12)
        .background(Color.daVeryLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            if let provider = providers.first {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, error) in
                    if let data = data as? Data, let droppedId = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            await notebookVM.setTodoStatus(status, for: droppedId, in: note)
                        }
                    }
                }
                return true
            }
            return false
        }
    }
    
    private func kanbanCard(_ todo: TodoItem, columnColor: Color) -> some View {
        let isHovered = hoveredTodoId == todo.id
        
        return VStack(alignment: .leading, spacing: 6) {
            Text(todo.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(todo.currentStatus == .done ? Color.daMutedText : Color.daPrimaryText)
                .strikethrough(todo.currentStatus == .done, color: Color.daMutedText.opacity(0.5))
            
            HStack {
                if let dueDate = todo.dueDate {
                    dueDateLabel(dueDate, isCompleted: todo.currentStatus == .done)
                }
                Spacer()
                
                // Quick actions
                if isHovered {
                    HStack(spacing: 8) {
                        if todo.currentStatus != .todo {
                            Button {
                                Task { await notebookVM.setTodoStatus(todo.currentStatus == .done ? .inProgress : .todo, for: todo.id, in: note) }
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.daMutedText)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if todo.currentStatus != .done {
                            Button {
                                Task { await notebookVM.setTodoStatus(todo.currentStatus == .todo ? .inProgress : .done, for: todo.id, in: note) }
                            } label: {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.daMutedText)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button {
                            Task { await notebookVM.deleteTodo(todo.id, in: note) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "EF4444"))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? columnColor.opacity(0.5) : Color.daBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        .onHover { hovering in
            hoveredTodoId = hovering ? todo.id : nil
        }
        .onDrag {
            NSItemProvider(object: todo.id as NSString)
        }
    }
    
    // MARK: - Todo Row
    private func todoRow(_ todo: TodoItem) -> some View {
        let isHovered = hoveredTodoId == todo.id
        
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Premium Checkbox
                Button {
                    Task {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {}
                        await notebookVM.toggleTodo(todo.id, in: note)
                    }
                } label: {
                    ZStack {
                        if todo.isCompleted {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.daGreen, Color.daEmerald],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 20, height: 20)
                                .shadow(color: Color.daGreen.opacity(0.3), radius: 3, y: 1)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Circle()
                                .stroke(
                                    isHovered ? Color.daAccent.opacity(0.5) : Color.daBorder,
                                    lineWidth: 1.5
                                )
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(isHovered ? Color.daLightBlue.opacity(0.3) : Color.clear)
                                )
                        }
                    }
                    .scaleEffect(todo.isCompleted ? 1.0 : (isHovered ? 1.1 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: todo.isCompleted)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                }
                .buttonStyle(.plain)
                
                // View configuration
                VStack(alignment: .leading, spacing: 6) {
                    // Text + Due info
                    VStack(alignment: .leading, spacing: 3) {
                        Text(todo.text)
                            .font(.system(size: 12.5, weight: todo.isCompleted ? .regular : .medium))
                            .foregroundStyle(todo.isCompleted ? Color.daMutedText : Color.daPrimaryText)
                            .strikethrough(todo.isCompleted, color: Color.daMutedText.opacity(0.5))
                        
                        HStack(spacing: 8) {
                            if let priority = todo.priority {
                                Text(priority.displayName)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(priority == .high ? Color(hex: "ef4444") : (priority == .medium ? Color.daOrange : Color.daAccent))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background((priority == .high ? Color(hex: "ef4444") : (priority == .medium ? Color.daOrange : Color.daAccent)).opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            if let assignee = todo.assignee {
                                HStack(spacing: 2) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 8))
                                    Text(assignee)
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundStyle(Color.daSecondaryText)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.daLightGray)
                                .clipShape(Capsule())
                            }
                            
                            if let dueDate = todo.dueDate {
                                dueDateLabel(dueDate, isCompleted: todo.isCompleted)
                            }
                        }
                        
                        if let tags = todo.tags, !tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(Color.daMutedText)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.daVeryLightGray)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .opacity(todo.isCompleted ? 0.7 : 1.0)
                    
                    // Subtasks
                    if let subTasks = todo.subTasks, !subTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(subTasks) { st in
                                HStack(spacing: 6) {
                                    Button {
                                        Task { await notebookVM.toggleSubTask(st.id, in: todo.id, note: note) }
                                    } label: {
                                        Image(systemName: st.isCompleted ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 11))
                                            .foregroundStyle(st.isCompleted ? Color.daGreen : Color.daMutedText)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Text(st.text)
                                        .font(.system(size: 11))
                                        .foregroundStyle(st.isCompleted ? Color.daMutedText : Color.daSecondaryText)
                                        .strikethrough(st.isCompleted, color: Color.daMutedText)
                                    
                                    if isHovered {
                                        Spacer()
                                        Button {
                                            Task { await notebookVM.deleteSubTask(st.id, in: todo.id, note: note) }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9))
                                                .foregroundStyle(Color.daMutedText)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 6)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                    }
                    
                    if isHovered || (newSubTaskText[todo.id] != nil && !newSubTaskText[todo.id]!.isEmpty) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.daMutedText)
                            TextField("Add sub-task...", text: Binding(
                                get: { newSubTaskText[todo.id] ?? "" },
                                set: { newSubTaskText[todo.id] = $0 }
                            ))
                            .font(.system(size: 10))
                            .textFieldStyle(.plain)
                            .onSubmit {
                                if let text = newSubTaskText[todo.id], !text.isEmpty {
                                    Task {
                                        await notebookVM.addSubTask(text, to: todo.id, in: note)
                                        newSubTaskText[todo.id] = ""
                                    }
                                }
                            }
                        }
                        .padding(.leading, 6)
                        .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 16)
                
                // Actions (visible on hover or when expanded)
                HStack(spacing: 4) {
                    // Due date button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if dueDateTodoId == todo.id {
                                dueDateTodoId = nil
                            } else {
                                dueDateTodoId = todo.id
                            }
                        }
                    } label: {
                        Image(systemName: todo.dueDate != nil ? "calendar.badge.clock" : "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(todo.dueDate != nil ? Color.daAccent : Color.daMutedText)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(dueDateTodoId == todo.id ? Color.daLightBlue : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Settings
                    Button {
                        settingsTodoId = todo.id
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.daMutedText)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(settingsTodoId == todo.id ? Color.daLightBlue : (isHovered ? Color.daLightGray : Color.clear))
                            )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: Binding(
                        get: { settingsTodoId == todo.id },
                        set: { if !$0 { settingsTodoId = nil } }
                    ), arrowEdge: .bottom) {
                        TodoSettingsView(notebookVM: notebookVM, note: note, todo: todo)
                    }
                    
                    // Delete
                    Button {
                        Task { await notebookVM.deleteTodo(todo.id, in: note) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.daMutedText)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isHovered ? Color.daLightGray : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .opacity(isHovered || dueDateTodoId == todo.id ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // Inline date picker
            if dueDateTodoId == todo.id {
                Divider().foregroundStyle(Color.daBorder.opacity(0.5))
                dueDatePicker(todo)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    todo.isCompleted ? Color.daLightGreen.opacity(0.15) :
                        isHovered ? Color.daLightBlue.opacity(0.2) :
                        Color.clear
                )
        )
        .padding(.horizontal, 6)
        .onHover { hovering in
            hoveredTodoId = hovering ? todo.id : nil
        }
    }
    
    // MARK: - Due Date Label
    private func dueDateLabel(_ date: Date, isCompleted: Bool) -> some View {
        let remaining = date.timeIntervalSince(Date())
        let isOverdue = remaining < 0 && !isCompleted
        
        let labelColor: Color = {
            if isCompleted { return Color.daMutedText }
            if isOverdue { return Color(hex: "EF4444") }
            if remaining < 3600 { return Color(hex: "F59E0B") }
            if remaining < 86400 { return Color(hex: "F59E0B").opacity(0.8) }
            return Color.daTertiaryText
        }()
        
        let iconName: String = {
            if isOverdue { return "exclamationmark.circle.fill" }
            if remaining < 3600 { return "flame.fill" }
            return "clock"
        }()
        
        return HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 9))
            Text(dueDateText(date))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(labelColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(labelColor.opacity(0.08))
        )
    }
    
    private func dueDateText(_ date: Date) -> String {
        let remaining = date.timeIntervalSince(Date())
        if remaining < 0 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "editor.overdue".localized(formatter.localizedString(for: date, relativeTo: Date()))
        }
        if remaining < 3600 {
            return "editor.minutesLeft".localized(Int(remaining / 60))
        }
        if remaining < 86400 {
            return "editor.hoursLeft".localized(Int(remaining / 3600))
        }
        if remaining < 604800 {
            return "editor.daysLeft".localized(Int(remaining / 86400))
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Due Date Picker
    private func dueDatePicker(_ todo: TodoItem) -> some View {
        HStack(spacing: 12) {
            DatePicker(
                "editor.due".localized,
                selection: Binding(
                    get: { todo.dueDate ?? Date() },
                    set: { newDate in
                        Task { await notebookVM.setDueDate(newDate, todoId: todo.id, in: note) }
                    }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .controlSize(.small)
            
            if todo.dueDate != nil {
                Button {
                    Task { await notebookVM.setDueDate(nil, todoId: todo.id, in: note) }
                    dueDateTodoId = nil
                } label: {
                    Text("editor.clear".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "EF4444"))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    dueDateTodoId = nil
                }
            } label: {
                Text("editor.done".localized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.daAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.daVeryLightGray)
    }
    
    // MARK: - Footer
    private var editorFooter: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.daGreen)
                    .frame(width: 5, height: 5)
                Text("editor.lastUpdated".localized(formattedDate(note.updatedAt)))
                    .font(.daSmallLabel)
                    .foregroundStyle(Color.daMutedText)
            }
            Spacer()
            Text("\(note.content.count) " + "editor.characters".localized)
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.daWhite)
        .overlay(alignment: .top) {
            Divider().foregroundStyle(Color.daBorder)
        }
    }
    
    // MARK: - Helpers
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var headerIconColor: Color {
        guard let customColor = note.colorCode else { return .daBlue }
        switch customColor {
        case "blue": return .daBlue
        case "red": return Color(hex: "EF4444")
        case "green": return .daGreen
        case "yellow": return Color(hex: "F59E0B")
        case "orange": return .daOrange
        case "purple": return Color(hex: "8B5CF6")
        default: return .daSecondaryText
        }
    }
    
    @ViewBuilder
    private var editorThemeBackground: some View {
        let theme = note.theme ?? "default"
        if theme == "dots" {
            Canvas { context, size in
                let step: CGFloat = 20
                for x in stride(from: step/2, to: size.width, by: step) {
                    for y in stride(from: step/2, to: size.height, by: step) {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x-1.5, y: y-1.5, width: 3, height: 3)),
                            with: .color(Color.daMutedText.opacity(0.25))
                        )
                    }
                }
            }
        } else if theme == "lines" {
            Canvas { context, size in
                let step: CGFloat = 28
                for y in stride(from: step, to: size.height, by: step) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(
                        path,
                        with: .color(Color.daAccent.opacity(0.1)),
                        lineWidth: 1
                    )
                }
            }
        }
    }
    
    // MARK: - Slash Commands
    private func slashCommandItem(title: String, icon: String, insertValue: String) -> some View {
        Button {
            // Remove the last slash character
            if let lastIndex = editingContent.lastIndex(of: "/") {
                editingContent.remove(at: lastIndex)
            }
            editingContent += insertValue
            showSlashCommands = false
            Task {
                await notebookVM.saveContent(editingContent, for: note)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 14)
                Text(title)
                    .font(.daBodyMedium)
                Spacer()
            }
            .foregroundStyle(Color.daPrimaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Snippets
    private func debounceSave(action: @escaping () async -> Void) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled {
                await action()
            }
        }
    }
}
