import Foundation

struct UnusedCodeResult: Identifiable, Codable {
    var id = UUID()
    let kind: String
    let name: String
    let location: String
    let hints: [String]
}
