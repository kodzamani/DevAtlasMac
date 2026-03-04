import SwiftUI

struct TodoSettingsView: View {
    @Bindable var notebookVM: NotebookViewModel
    let note: NotebookNote
    let todo: TodoItem
    @Environment(\.dismiss) private var dismiss
    
    @State private var priority: TodoPriority?
    @State private var assignee: String
    @State private var tagsText: String
    
    init(notebookVM: NotebookViewModel, note: NotebookNote, todo: TodoItem) {
        self.notebookVM = notebookVM
        self.note = note
        self.todo = todo
        _priority = State(initialValue: todo.priority)
        _assignee = State(initialValue: todo.assignee ?? "")
        _tagsText = State(initialValue: todo.tags?.joined(separator: ", ") ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("notebook.todoDetails".localized)
                .font(.daSectionTitle)
                .foregroundStyle(Color.daPrimaryText)
            
            Divider()
            
            // Priority
            VStack(alignment: .leading, spacing: 6) {
                Text("notebook.priority".localized)
                    .font(.daSmallLabelSemiBold)
                    .foregroundStyle(Color.daSecondaryText)
                Picker("", selection: $priority) {
                    Text("notebook.none".localized).tag(TodoPriority?.none)
                    ForEach(TodoPriority.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(TodoPriority?.some(p))
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Assignee
            VStack(alignment: .leading, spacing: 6) {
                Text("notebook.assignee".localized)
                    .font(.daSmallLabelSemiBold)
                    .foregroundStyle(Color.daSecondaryText)
                TextField("e.g. John Doe", text: $assignee)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 6) {
                Text("notebook.tagsCommaSeparated".localized)
                    .font(.daSmallLabelSemiBold)
                    .foregroundStyle(Color.daSecondaryText)
                TextField("e.g. urgent, backend", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("common.cancel".localized) {
                    dismiss()
                }
                Spacer()
                Button("common.save".localized) {
                    let parsedTags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    Task {
                        await notebookVM.updateTodoDetails(
                            priority: priority,
                            assignee: assignee.isEmpty ? nil : assignee,
                            tags: parsedTags.isEmpty ? nil : parsedTags,
                            for: todo.id,
                            in: note
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(20)
        .frame(width: 300, height: 350)
    }
}
