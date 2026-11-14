import Foundation

/// What a regenerable folder holds, used to group and filter the cache list.
enum CacheKind: String, CaseIterable, Hashable, Sendable {
    case nodeModules
    case derivedData
    case buildOutput
    case packages
    case frameworkCache
    case toolCache
    case virtualEnv

    var titleKey: String { "cache.kind.\(rawValue)" }
}

/// One folder a project can rebuild on its own, and so can be removed to free space.
struct CacheItem: Identifiable, Hashable, Sendable {
    var id: String { path }
    let path: String
    /// The path as shown to the user: relative to the project, or the DerivedData folder name.
    let displayName: String
    let kind: CacheKind
    var size: Int64 = 0
}
