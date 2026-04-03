import Foundation
import Network
import Observation

extension Notification.Name {
    static let connectivityStatusDidChange = Notification.Name("ConnectivityMonitor.statusDidChange")
}

enum ConnectivityStatus: String, Equatable, Sendable {
    case unknown
    case connected
    case disconnected

    var isConnected: Bool {
        self == .connected
    }
}

enum ConnectivityStatusNotificationKey {
    static let previousStatus = "previousStatus"
    static let currentStatus = "currentStatus"
    static let isConnected = "isConnected"
}

@MainActor
@Observable
final class ConnectivityMonitor {
    private(set) var status: ConnectivityStatus

    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?

    var isConnected: Bool {
        status.isConnected
    }

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        status = .unknown
        monitoringTask = Task { @MainActor [weak self] in
            for await updatedStatus in Self.liveStatusUpdates() {
                self?.applyStatus(updatedStatus)
            }
        }
    }

    init(
        statusUpdates: AsyncStream<ConnectivityStatus>,
        notificationCenter: NotificationCenter = .default
    ) {
        self.notificationCenter = notificationCenter
        status = .unknown
        monitoringTask = Task { @MainActor [weak self] in
            for await updatedStatus in statusUpdates {
                self?.applyStatus(updatedStatus)
            }
        }
    }

    deinit {
        monitoringTask?.cancel()
    }

    private func applyStatus(_ updatedStatus: ConnectivityStatus) {
        guard status != updatedStatus else {
            return
        }

        let previousStatus = status
        status = updatedStatus

        notificationCenter.post(
            name: .connectivityStatusDidChange,
            object: self,
            userInfo: [
                ConnectivityStatusNotificationKey.previousStatus: previousStatus.rawValue,
                ConnectivityStatusNotificationKey.currentStatus: updatedStatus.rawValue,
                ConnectivityStatusNotificationKey.isConnected: updatedStatus.isConnected
            ]
        )
    }

    private static func liveStatusUpdates(
        queue: DispatchQueue = DispatchQueue(label: "ConnectivityMonitor.queue")
    ) -> AsyncStream<ConnectivityStatus> {
        let pathMonitor = NWPathMonitor()

        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let monitorTask = Task {
                pathMonitor.start(queue: queue)

                defer {
                    pathMonitor.cancel()
                    continuation.finish()
                }

                for await path in pathMonitor {
                    if Task.isCancelled {
                        break
                    }

                    continuation.yield(ConnectivityStatus(path.status))
                }
            }

            continuation.onTermination = { _ in
                monitorTask.cancel()
            }
        }
    }
}

private extension ConnectivityStatus {
    nonisolated init(_ pathStatus: NWPath.Status) {
        switch pathStatus {
        case .satisfied:
            self = .connected
        case .requiresConnection, .unsatisfied:
            self = .disconnected
        @unknown default:
            self = .disconnected
        }
    }
}
