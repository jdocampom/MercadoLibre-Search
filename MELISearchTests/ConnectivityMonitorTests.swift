import Foundation
import Testing
@testable import MELISearch

@MainActor
struct ConnectivityMonitorTests {
    @Test
    func updatesStatusWhenConnectivityChanges() async {
        let (statusUpdates, continuation) = AsyncStream.makeStream(
            of: ConnectivityStatus.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let monitor = ConnectivityMonitor(
            statusUpdates: statusUpdates,
            notificationCenter: NotificationCenter()
        )

        #expect(monitor.status == .unknown)

        continuation.yield(.connected)
        await waitUntil { monitor.status == .connected }

        #expect(monitor.status == .connected)
        #expect(monitor.isConnected)

        continuation.finish()
    }

    @Test
    func emitsNotificationOnlyForRealStatusChanges() async {
        let (statusUpdates, continuation) = AsyncStream.makeStream(
            of: ConnectivityStatus.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let notificationCenter = NotificationCenter()
        let monitor = ConnectivityMonitor(
            statusUpdates: statusUpdates,
            notificationCenter: notificationCenter
        )

        let recorder = NotificationRecorder()
        let previousStatusKey = "previousStatus"
        let currentStatusKey = "currentStatus"
        let isConnectedKey = "isConnected"
        let observer = notificationCenter.addObserver(
            forName: .connectivityStatusDidChange,
            object: monitor,
            queue: nil
        ) { notification in
            let previousStatus = notification.userInfo?[previousStatusKey] as? String
            let currentStatus = notification.userInfo?[currentStatusKey] as? String
            let isConnected = notification.userInfo?[isConnectedKey] as? Bool

            if let previousStatus, let currentStatus, let isConnected {
                Task {
                    await recorder.append(
                        (previous: previousStatus, current: currentStatus, isConnected: isConnected)
                    )
                }
            }
        }
        defer { notificationCenter.removeObserver(observer) }

        continuation.yield(.connected)
        await waitUntilRecordedCount(1, in: recorder)

        continuation.yield(.connected)
        await waitUntilRecordedCount(1, in: recorder)

        continuation.yield(.disconnected)
        await waitUntilRecordedCount(2, in: recorder)

        let receivedStatuses = await recorder.values
        #expect(receivedStatuses.count == 2)
        #expect(receivedStatuses[0].previous == ConnectivityStatus.unknown.rawValue)
        #expect(receivedStatuses[0].current == ConnectivityStatus.connected.rawValue)
        #expect(receivedStatuses[0].isConnected)
        #expect(receivedStatuses[1].previous == ConnectivityStatus.connected.rawValue)
        #expect(receivedStatuses[1].current == ConnectivityStatus.disconnected.rawValue)
        #expect(receivedStatuses[1].isConnected == false)

        continuation.finish()
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let start = ContinuousClock.now

        while !condition() {
            if ContinuousClock.now - start > .nanoseconds(timeoutNanoseconds) {
                break
            }

            await Task.yield()
        }
    }

    private func waitUntilRecordedCount(
        _ expectedCount: Int,
        in recorder: NotificationRecorder,
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async {
        let start = ContinuousClock.now

        while await recorder.count < expectedCount {
            if ContinuousClock.now - start > .nanoseconds(timeoutNanoseconds) {
                break
            }

            await Task.yield()
        }
    }
}

private actor NotificationRecorder {
    private(set) var values: [(previous: String, current: String, isConnected: Bool)] = []

    var count: Int {
        values.count
    }

    func append(_ value: (previous: String, current: String, isConnected: Bool)) {
        values.append(value)
    }
}
