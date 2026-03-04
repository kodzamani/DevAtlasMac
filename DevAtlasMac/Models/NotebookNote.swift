import Foundation

struct NotebookNote: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var projectId: String
    var projectName: String
    var title: String
    var content: String
    var todos: [TodoItem]
    var createdAt: Date
    var updatedAt: Date
    
    // New Feature Properties
    var tags: [String]?
    var isArchived: Bool? = false
    var isPinned: Bool? = false
    var colorCode: String?
    var iconName: String?
    var theme: String? // e.g., "dots", "lines", "default"
    var folder: String?
    var attachments: [NoteAttachment]?
}
