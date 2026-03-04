import Foundation

struct NoteAttachment: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
}
