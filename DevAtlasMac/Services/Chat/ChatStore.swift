import Foundation

/// Keeps the Chat tab's conversations on disk, next to the notebooks.
actor ChatStore {
    static let shared = ChatStore()
    static let maxConversations = 30

    private let fileManager = FileManager.default

    private var storeFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let devAtlasDir = appSupport.appendingPathComponent("DevAtlas")
        try? fileManager.createDirectory(at: devAtlasDir, withIntermediateDirectories: true)
        return devAtlasDir.appendingPathComponent("chat_conversations.json")
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - Load / Save

    /// Newest first. Anything still marked as running was interrupted by a quit, so it is shown as failed.
    func loadConversations() -> [ChatConversation] {
        guard let data = try? Data(contentsOf: storeFileURL),
              let store = try? makeDecoder().decode(ChatStoreData.self, from: data)
        else { return [] }

        let conversations = store.conversations.map { conversation -> ChatConversation in
            var conversation = conversation
            for index in conversation.messages.indices {
                if case .running = conversation.messages[index].status {
                    conversation.messages[index].status = .failed
                }
            }
            return conversation
        }
        return Self.trimmed(conversations)
    }

    func saveConversations(_ conversations: [ChatConversation]) {
        let store = ChatStoreData(conversations: Self.trimmed(conversations.filter { !$0.messages.isEmpty }))
        if let data = try? makeEncoder().encode(store) {
            try? data.write(to: storeFileURL, options: .atomic)
        }
    }

    static func trimmed(_ conversations: [ChatConversation]) -> [ChatConversation] {
        Array(conversations.sorted { $0.updatedAt > $1.updatedAt }.prefix(maxConversations))
    }
}

// MARK: - Store Data

private struct ChatStoreData: Codable {
    var version = 1
    let conversations: [ChatConversation]
}
