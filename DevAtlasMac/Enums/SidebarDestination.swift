import Foundation

/// A row in the app sidebar.
enum SidebarDestination: Hashable {
    case category(String)
    case tag(String)
    case tab(AppTab)
}
