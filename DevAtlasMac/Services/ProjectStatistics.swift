import Foundation


enum ProjectStatistics {
    static func calculate(for project: ProjectInfo) async -> ProjectStats {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = calculateSync(for: project)
                continuation.resume(returning: result)
            }
        }
    }

    private static func calculateSync(for project: ProjectInfo) -> ProjectStats {
        var stats = ProjectStats()
        let fm = FileManager.default
        let url = URL(fileURLWithPath: project.path)

        var totalBytes: Int64 = 0

        let skipDirs: Set<String> = [
            "node_modules", ".git", "build", "dist", ".next",
            "__pycache__", ".venv", "venv", "Pods", "DerivedData",
            ".build", "target", "bin", "obj"
        ]

        if let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let name = fileURL.lastPathComponent
                if skipDirs.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }

                guard let values = try? fileURL.resourceValues(
                    forKeys: [.isRegularFileKey, .fileSizeKey]
                ), values.isRegularFile == true else { continue }

                totalBytes += Int64(values.fileSize ?? 0)
            }
        }

        stats.totalSize = formatBytes(totalBytes)

        return stats
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
