import Foundation

struct FileLineInfo: Identifiable {
    let id = UUID()
    let relativePath: String
    let fileExtension: String
    let lineCount: Int
}
