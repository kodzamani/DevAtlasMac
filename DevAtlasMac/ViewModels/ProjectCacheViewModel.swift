import SwiftUI
import Combine

/// One project and the cache folders found in it.
struct ProjectCacheGroup: Identifiable {
    let project: ProjectInfo
    var items: [CacheItem]

    var id: String { project.id }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

enum CacheSortOption: String, CaseIterable, Identifiable {
    case size
    case name
    case oldest

    var id: String { rawValue }
    var title: String { "cache.sort.\(rawValue)".localized }
}

enum CacheSelectionState {
    case none
    case some
    case all
}

struct CacheCleanResult: Equatable {
    var freedBytes: Int64
    var failedCount: Int
}

@MainActor
final class ProjectCacheViewModel: ObservableObject {
    // MARK: - State

    @Published private(set) var groups: [ProjectCacheGroup] = []
    @Published private(set) var isScanning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var scannedProjects = 0
    @Published private(set) var totalProjects = 0

    /// Paths of the folders picked for cleaning.
    @Published var selection: Set<String> = []
    /// Projects whose folders are listed.
    @Published var expanded: Set<String> = []
    @Published var kindFilter: CacheKind?
    @Published var sort: CacheSortOption = .size

    @Published private(set) var isCleaning = false
    @Published var lastResult: CacheCleanResult?

    private var scanTask: Task<Void, Never>?
    private static let concurrentScans = 4

    // MARK: - Totals

    private var allItems: [CacheItem] { groups.flatMap(\.items) }

    var totalSize: Int64 { groups.reduce(0) { $0 + $1.totalSize } }
    var folderCount: Int { groups.reduce(0) { $0 + $1.items.count } }
    var largestGroup: ProjectCacheGroup? { groups.max { $0.totalSize < $1.totalSize } }

    var selectedCount: Int { allItems.filter { selection.contains($0.path) }.count }
    var selectedSize: Int64 {
        allItems.reduce(0) { selection.contains($1.path) ? $0 + $1.size : $0 }
    }

    /// Kinds present in the results, largest first.
    var sizeByKind: [(kind: CacheKind, size: Int64)] {
        var sizes: [CacheKind: Int64] = [:]
        for item in allItems { sizes[item.kind, default: 0] += item.size }
        return sizes
            .map { (kind: $0.key, size: $0.value) }
            .sorted { ($0.size, $1.kind.rawValue) > ($1.size, $0.kind.rawValue) }
    }

    /// The list as shown: narrowed by kind and search text, then sorted.
    func visibleGroups(matching searchText: String) -> [ProjectCacheGroup] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        var result = groups.compactMap { group -> ProjectCacheGroup? in
            if !query.isEmpty,
               !group.project.name.lowercased().contains(query),
               !group.project.path.lowercased().contains(query),
               !group.project.projectType.lowercased().contains(query) {
                return nil
            }
            guard let kindFilter else { return group }
            let items = group.items.filter { $0.kind == kindFilter }
            return items.isEmpty ? nil : ProjectCacheGroup(project: group.project, items: items)
        }

        switch sort {
        case .size:
            result.sort { ($0.totalSize, $1.project.name) > ($1.totalSize, $0.project.name) }
        case .name:
            result.sort { $0.project.name.localizedStandardCompare($1.project.name) == .orderedAscending }
        case .oldest:
            result.sort { $0.project.lastModified < $1.project.lastModified }
        }
        return result
    }

    // MARK: - Scanning

    func scanIfNeeded(_ projects: [ProjectInfo]) {
        guard !hasScanned, !projects.isEmpty else { return }
        scan(projects)
    }

    func scan(_ projects: [ProjectInfo]) {
        scanTask?.cancel()
        hasScanned = true
        isScanning = true
        groups = []
        selection = []
        lastResult = nil
        scannedProjects = 0
        totalProjects = projects.count

        scanTask = Task {
            let paths = projects.map(\.path)
            let roots = Set(paths)
            let derivedData = await Task.detached(priority: .utility) {
                ProjectCacheScanner.derivedData(forProjectsAt: paths)
            }.value

            await withTaskGroup(of: ProjectCacheGroup.self) { taskGroup in
                var remaining = projects.makeIterator()

                func startNext() {
                    guard let project = remaining.next() else { return }
                    let extra = derivedData[project.path] ?? []
                    taskGroup.addTask(priority: .utility) {
                        Self.measure(project, skipping: roots, derivedData: extra)
                    }
                }

                for _ in 0..<Self.concurrentScans { startNext() }

                while let group = await taskGroup.next() {
                    if Task.isCancelled {
                        taskGroup.cancelAll()
                        break
                    }
                    scannedProjects += 1
                    if !group.items.isEmpty { groups.append(group) }
                    startNext()
                }
            }

            // A newer scan owns the state once this one is cancelled.
            guard !Task.isCancelled else { return }
            isScanning = false
        }
    }

    nonisolated private static func measure(
        _ project: ProjectInfo,
        skipping roots: Set<String>,
        derivedData: [CacheItem]
    ) -> ProjectCacheGroup {
        var items = ProjectCacheScanner.caches(inProjectAt: project.path, skipping: roots)

        for var item in derivedData where !items.contains(where: { $0.path == item.path }) {
            item.size = ProjectCacheScanner.directorySize(atPath: item.path)
            if item.size > 0 { items.append(item) }
        }

        items.sort { ($0.size, $1.displayName) > ($1.size, $0.displayName) }
        return ProjectCacheGroup(project: project, items: items)
    }

    // MARK: - Selection

    func isSelected(_ item: CacheItem) -> Bool {
        selection.contains(item.path)
    }

    func toggle(_ item: CacheItem) {
        if selection.contains(item.path) {
            selection.remove(item.path)
        } else {
            selection.insert(item.path)
        }
    }

    func selectionState(of items: [CacheItem]) -> CacheSelectionState {
        let selected = items.filter { selection.contains($0.path) }.count
        if selected == 0 { return .none }
        return selected == items.count ? .all : .some
    }

    /// Selects every given folder, or clears them when they are all selected already.
    func toggle(_ items: [CacheItem]) {
        let paths = items.map(\.path)
        if selectionState(of: items) == .all {
            selection.subtract(paths)
        } else {
            selection.formUnion(paths)
        }
    }

    func select(_ groups: [ProjectCacheGroup]) {
        selection.formUnion(groups.flatMap(\.items).map(\.path))
    }

    /// Selects the caches of projects nobody has touched for the given number of days.
    func select(_ groups: [ProjectCacheGroup], untouchedForDays days: Int) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        selection = []
        select(groups.filter { $0.project.lastModified < cutoff })
    }

    func toggleExpansion(of group: ProjectCacheGroup) {
        if expanded.contains(group.id) {
            expanded.remove(group.id)
        } else {
            expanded.insert(group.id)
        }
    }

    // MARK: - Cleaning

    /// Removes the selected folders one by one, so the list empties as space is freed.
    func cleanSelection(toTrash: Bool) {
        guard !isCleaning else { return }
        let targets = allItems.filter { selection.contains($0.path) }
        guard !targets.isEmpty else { return }

        isCleaning = true
        lastResult = nil

        Task {
            var result = CacheCleanResult(freedBytes: 0, failedCount: 0)

            for target in targets {
                let removed = await Task.detached(priority: .userInitiated) {
                    do {
                        try ProjectCacheScanner.remove(target.path, toTrash: toTrash)
                        return true
                    } catch {
                        // Already gone counts as cleaned.
                        return !FileManager.default.fileExists(atPath: target.path)
                    }
                }.value

                if removed {
                    result.freedBytes += target.size
                    forget(target)
                } else {
                    result.failedCount += 1
                }
            }

            selection.subtract(targets.map(\.path))
            lastResult = result
            isCleaning = false
        }
    }

    private func forget(_ item: CacheItem) {
        selection.remove(item.path)
        guard let index = groups.firstIndex(where: { $0.items.contains { $0.path == item.path } }) else { return }
        groups[index].items.removeAll { $0.path == item.path }
        if groups[index].items.isEmpty { groups.remove(at: index) }
    }
}
