import Foundation

actor ProjectIndex {
    private let fileManager = FileManager.default
    private var cachedProjects: [ProjectInfo]?

    private var indexFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let devAtlasDir = appSupport.appendingPathComponent("DevAtlas")
        try? fileManager.createDirectory(at: devAtlasDir, withIntermediateDirectories: true)
        return devAtlasDir.appendingPathComponent("project_index.json")
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }

    // MARK: - Load / Save

    func loadProjects() -> [ProjectInfo] {
        if let cached = cachedProjects { return cached }

        guard let data = try? Data(contentsOf: indexFileURL),
              let index = try? makeDecoder().decode(IndexData.self, from: data)
        else { return [] }

        cachedProjects = index.projects
        return index.projects
    }

    func saveProjects(_ projects: [ProjectInfo]) {
        let limited = Array(projects.prefix(200))
        let index = IndexData(
            projects: limited,
            lastIndexed: Date()
        )

        if let data = try? makeEncoder().encode(index) {
            try? data.write(to: indexFileURL, options: .atomic)
        }
        cachedProjects = limited
    }

    // MARK: - Cache Status

    func needsRescan() -> Bool {
        guard let data = try? Data(contentsOf: indexFileURL),
              let index = try? makeDecoder().decode(IndexData.self, from: data)
        else { return true }

        return Date().timeIntervalSince(index.lastIndexed) > 86400
    }

}

// MARK: - Index Data

private struct IndexData: Codable {
    let projects: [ProjectInfo]
    let lastIndexed: Date
}
