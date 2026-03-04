import Foundation

struct ScanProgress: Sendable {
    var currentPath: String = ""
    var projectsFound: Int = 0
    var directoriesScanned: Int = 0
    var progressPercentage: Double = 0.0
    var isScanning: Bool = false

    nonisolated init() {}
}
