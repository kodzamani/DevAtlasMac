import Foundation

struct GitDailyStat: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let projectName: String
    let additions: Int
    let deletions: Int
    let commits: Int
    
    var totalChanges: Int {
        additions + deletions
    }
}
