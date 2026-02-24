import Foundation
import Combine
import WatchConnectivity

// MARK: - WatchConnector

final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnector()

    @Published var isWatchReachable = false
    @Published var lastReceivedMessage: [String: Any] = [:]

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send Snapshot to Watch

    func sendSnapshotToWatch(_ snapshot: ZFlowSnapshot) {
        guard WCSession.default.isReachable else {
            transferSnapshotContext(snapshot)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        WCSession.default.sendMessageData(data, replyHandler: nil) { _ in
            self.transferSnapshotContext(snapshot)
        }
    }

    private func transferSnapshotContext(_ snapshot: ZFlowSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext(["snapshot": data])
    }

    // MARK: - Send Budget Alert to Watch

    func sendBudgetAlertToWatch(_ payload: BudgetAlertPayload) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(["budgetAlert": data])
        }
    }

    // MARK: - Receive Quick-Add from Watch

    private func handleQuickAdd(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let item = try? decoder.decode(WatchQuickAdd.self, from: data) else { return }
        NotificationCenter.default.post(name: .zflowWatchQuickAdd, object: item)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.isWatchReachable = state == .activated }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        handleQuickAdd(data: messageData)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo["quickAdd"] as? Data { handleQuickAdd(data: data) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        DispatchQueue.main.async { self.lastReceivedMessage = context }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}

// MARK: - Watch Quick Add Model

struct WatchQuickAdd: Codable {
    var amount: Double
    var currency: String
    var type: String
    var categoryId: UUID?
    var note: String?
    var date: Date
}

extension Notification.Name {
    static let zflowWatchQuickAdd = Notification.Name("com.zflow.watchQuickAdd")
}
