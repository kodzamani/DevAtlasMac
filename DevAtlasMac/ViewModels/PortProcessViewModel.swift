import Foundation
import Observation

@MainActor
@Observable
final class PortProcessViewModel {
    nonisolated init() {}

    private(set) var listeners: [PortListener] = []
    private(set) var isScanning = false
    private(set) var stoppingPIDs: Set<Int32> = []
    private(set) var lastUpdated: Date?
    var errorMessage: String?
    @ObservationIgnored private var scanTask: Task<Void, Never>?

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
