import Foundation
import Combine

@MainActor
final class PortProcessViewModel: ObservableObject {
    nonisolated init() {}

    @Published private(set) var listeners: [PortListener] = []
    @Published private(set) var isScanning = false
    @Published private(set) var stoppingPIDs: Set<Int32> = []
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    private var scanTask: Task<Void, Never>?

    func refresh() async {
        if let scanTask { await scanTask.value; return }
        isScanning = true
        let task = Task { [weak self] in
            let result = await Task.detached(priority: .utility) { Result { try PortProcessService.scan() } }.value
            guard let self else { return }
            switch result {
            case .success(let rows):
                listeners = rows
                lastUpdated = Date()
                errorMessage = nil
            case .failure(let error): errorMessage = error.localizedDescription
            }
            isScanning = false
        }
        scanTask = task
        await task.value
        scanTask = nil
    }

    func stop(_ listener: PortListener) async {
        guard stoppingPIDs.insert(listener.pid).inserted else { return }
        defer { stoppingPIDs.remove(listener.pid) }
        let result = await Task.detached(priority: .userInitiated) {
            Result { try PortProcessService.terminate(listener) }
        }.value
        switch result {
        case .success:
            await refresh()
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }
}
