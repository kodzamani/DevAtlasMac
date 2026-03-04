import Foundation

enum NotebookSearchScope: String, CaseIterable {
    case allNotes = "All Notes"
    case currentProject = "Current Project"
    case contentOnly = "Within Content"
    case byTags = "By Category/Tags"
    
    var displayText: String {
        return self.rawValue
    }
}
