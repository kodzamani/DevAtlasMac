import Foundation

actor NotebookStore {
    static let shared = NotebookStore()
    private let fileManager = FileManager.default
    private var cachedNotes: [NotebookNote]?

    private var storeFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let devAtlasDir = appSupport.appendingPathComponent("DevAtlas")
        try? fileManager.createDirectory(at: devAtlasDir, withIntermediateDirectories: true)
        return devAtlasDir.appendingPathComponent("notebooks.json")
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

    func loadNotes() -> [NotebookNote] {
        if let cached = cachedNotes { return cached }

        guard let data = try? Data(contentsOf: storeFileURL),
              let store = try? makeDecoder().decode(NotebookStoreData.self, from: data)
        else { return [] }

        cachedNotes = store.notes
        return store.notes
    }

    func saveNotes(_ notes: [NotebookNote]) {
        let store = NotebookStoreData(notes: notes)
        if let data = try? makeEncoder().encode(store) {
            try? data.write(to: storeFileURL, options: .atomic)
        }
        cachedNotes = notes
    }

    // MARK: - CRUD

    func addNote(_ note: NotebookNote) -> [NotebookNote] {
        var notes = loadNotes()
        notes.insert(note, at: 0)
        saveNotes(notes)
        return notes
    }

    func updateNote(_ note: NotebookNote) -> [NotebookNote] {
        var notes = loadNotes()
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
            saveNotes(notes)
        }
        return notes
    }

    func deleteNote(id: String) -> [NotebookNote] {
        var notes = loadNotes()
        notes.removeAll { $0.id == id }
        saveNotes(notes)
        return notes
    }
    
    func duplicateNote(id: String) -> [NotebookNote] {
        var notes = loadNotes()
        if let original = notes.first(where: { $0.id == id }) {
            var copy = original
            copy.id = UUID().uuidString
            copy.title = original.title + " (Copy)"
            copy.createdAt = Date()
            copy.updatedAt = Date()
            notes.insert(copy, at: 0)
            saveNotes(notes)
        }
        return notes
    }
}

// MARK: - Store Data

private struct NotebookStoreData: Codable {
    let notes: [NotebookNote]
}
