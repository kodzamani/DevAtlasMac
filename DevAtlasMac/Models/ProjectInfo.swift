import Foundation

struct ProjectInfo: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var path: String
    var projectType: String
    var category: ProjectCategory
    var tags: [String]
    var lastModified: Date
    var isActive: Bool
    var gitBranch: String?
    var iconColor: String?
    var totalFiles: Int?
    var totalLines: Int?

    var displayIconText: String {
        languageAbbreviation(for: projectType)
    }

    var iconSystemImage: String? {
        let swiftTypes = ["iOS", "Swift", "Xcode", "Xcode Workspace"]
        return swiftTypes.contains(projectType) ? "swift" : nil
    }

    var iconAssetName: String? {
        return projectType == "Flutter" ? "flutter_icon" : nil
    }

    var isAppleProject: Bool {
        let types = ["iOS", "Swift", "Xcode", "Xcode Workspace"]
        if types.contains(projectType) { return true }
        
        let tagsLower = tags.map { $0.lowercased() }
        let keywords = ["swift", "ios", "xcode"]
        for keyword in keywords {
            if tagsLower.contains(keyword) { return true }
        }
        return false
    }

    private func languageAbbreviation(for type: String) -> String {
        let mapping: [String: String] = [
            "Node.js": "JS",
            "React Native": "RN",
            "Next.js": "JS",
            "Vite": "JS",
            "Vue": "JS",
            "Angular": "TS",
            "React": "JS",
            ".NET": "C#",
            ".NET Solution": "C#",
            "F#": "F#",
            "VB.NET": "VB",
            "Go": "Go",
            "Rust": "Rs",
            "Java/Maven": "Jv",
            "Java/Gradle": "Jv",
            "PHP": "Ph",
            "Ruby": "Rb",
            "Python": "Py",
            "Flutter": "Fl",
            "iOS": "Sw",
            "Swift": "Sw",
            "Docker": "Dk",
            "Xcode": "Sw",
            "Xcode Workspace": "Sw"
        ]
        return mapping[type] ?? String(type.prefix(2)).uppercased()
    }

    var displayIconColor: String {
        if iconSystemImage == "swift" {
            return "FA7343"
        }
        return iconColor ?? generateColorFromType(projectType)
    }

    private func generateColorFromType(_ type: String) -> String {
        let colors = [
            "3B82F6", "8B5CF6", "EC4899", "F59E0B",
            "10B981", "EF4444", "6366F1", "14B8A6",
            "F97316", "06B6D4", "84CC16", "E11D48"
        ]
        let hash = abs(type.hashValue)
        return colors[hash % colors.count]
    }
}
