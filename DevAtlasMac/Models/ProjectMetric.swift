import Foundation

struct ProjectMetric: Identifiable, Equatable {
    let id = UUID()
    let projectName: String
    let projectType: String
    let value: Int
}
