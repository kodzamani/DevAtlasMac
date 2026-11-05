import Foundation

enum TodoStatus: String, Codable, Hashable {
    case todo = "In-Task"
    case inProgress = "Yapılıyor"
    case done = "Finish"
    
    var title: String {
        switch self {
        case .todo: return "editor.todoStatus.todo".localized
        case .inProgress: return "editor.todoStatus.inProgress".localized
        case .done: return "editor.todoStatus.done".localized
        }
    }
}
