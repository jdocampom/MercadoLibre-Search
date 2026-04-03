import Foundation
import Network
import Observation

extension Notification.Name {
    /// A notification posted whenever the connectivity monitor transitions between known states.
    static let connectivityStatusDidChange = Notification.Name("ConnectivityMonitor.statusDidChange")
}

/// Defines all possible network connectivity state consumed by the UI and tests.
enum ConnectivityStatus: String, Equatable, Sendable {
    /// The app has not received a path update yet.
    case unknown
    /// The current network path can satisfy outgoing requests.
    case connected
    /// The current network path cannot satisfy outgoing requests.
    case disconnected

    /// Indicates whether the current connectivity state can satisfy live network calls.
    var isConnected: Bool {
        self == .connected
    }
}

/// The notification payload keys emitted with connectivity status changes.
enum ConnectivityStatusNotificationKey {
    /// Key for the previous `ConnectivityStatus.rawValue`.
    static let previousStatus = "previousStatus"
    /// Key for the current `ConnectivityStatus.rawValue`.
    static let currentStatus = "currentStatus"
    /// Key for the boolean connectivity convenience flag.
    static let isConnected = "isConnected"
}

/// An object that observes system reachability updates and exposes them through
/// Observation-friendly state.
@Observable
@MainActor final class ConnectivityMonitor {
    /// The current connectivity state derived from `NWPathMonitor`.
    private(set) var status: ConnectivityStatus

    /// Notification center used to broadcast status changes to non-SwiftUI observers.
    @ObservationIgnored private let notificationCenter: NotificationCenter
    /// Task that bridges the active status stream into observable state updates.
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?

    /// Mirrors the status enum for simpler call sites in the UI.
    var isConnected: Bool {
        status.isConnected
    }

    /// Starts listening to live path updates using the system network monitor.
    /// - Parameter notificationCenter: Notification center used to broadcast status changes.
    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        status = .unknown
        monitoringTask = Task { @MainActor [weak self] in
            for await updatedStatus in Self.liveStatusUpdates() {
                self?.applyStatus(updatedStatus)
            }
        }
    }

    /// Test-only initializer that injects a custom stream of connectivity updates.
    /// - Parameters:
    ///   - statusUpdates: Stream that emits mocked connectivity transitions.
    ///   - notificationCenter: Notification center used to broadcast status changes.
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

    /// Stops the underlying monitoring task when the monitor leaves memory.
    deinit {
        monitoringTask?.cancel()
    }

    /// Applies a new status and broadcasts the transition only when the value changes.
    /// - Parameter updatedStatus: Connectivity value produced by the active monitor stream.
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

    /// Bridges `NWPathMonitor` updates into an async sequence scoped to the monitor lifetime.
    /// - Parameter queue: Dispatch queue used to run `NWPathMonitor`.
    /// - Returns: An async stream that emits connectivity transitions.
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
    /// Maps the low-level network path status into the UI-focused connectivity model.
    /// - Parameter pathStatus: Reachability status emitted by `NWPathMonitor`.
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
