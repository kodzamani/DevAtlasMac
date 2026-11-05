import Foundation

/// A place the user can navigate to, recorded for back/forward history.
struct BrowserLocation: Equatable {
    var tab: AppTab
    var category: String
    var tag: String?
    var projectID: String?
    var isAnalyzingProject = false
}
