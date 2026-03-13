import Foundation
import Combine
import WatchConnectivity
import WatchKit
import SwiftUI

@MainActor
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchStore()

    @Published var snapshot: ZFlowSnapshot = SnapshotStore.shared.load()
    @Published var budgetAlerts: [BudgetAlertPayload] = []
    @Published var showBudgetAlert: BudgetAlertPayload? = nil
    @Published var isConnected = false
    @Published var currentLanguage: String = AppGroup.defaults.string(forKey: AppGroup.Key.language) ?? "en"

    private let alertSeenKey = "watch.alertsSeen"
    private var seenAlertIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: alertSeenKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: alertSeenKey) }
    }

    // MARK: - Dynamic Theme
    var accentPrimary: Color {
        if let hex = snapshot.accentPrimaryHex { return wColor(hex) }
        return wColor("#5E5CE6")
    }

    var accentSecondary: Color {
        if let hex = snapshot.accentSecondaryHex { return wColor(hex) }
        return wColor("#7C3AED")
    }

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        checkBudgetAlerts()

        // Observe language changes from AppGroup
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                let newLang = AppGroup.defaults.string(forKey: AppGroup.Key.language) ?? "en"
                if self?.currentLanguage != newLang {
                    self?.currentLanguage = newLang
                }
            }
            .store(in: &cancellables)
    }

    func updateLanguage(_ lang: String) {
        currentLanguage = lang
        AppGroup.defaults.set(lang, forKey: AppGroup.Key.language)
        AppGroup.defaults.synchronize()
        // Notify localizer if it exists on watch
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }

    // MARK: - Budget Alert Check

    func checkBudgetAlerts() {
        let critical = snapshot.budgetStatuses.filter { $0.ratio >= 0.80 }
        for budget in critical {
            let threshold: BudgetAlertPayload.AlertType =
                budget.ratio >= 1.00 ? .exceeded :
                budget.ratio >= 0.95 ? .critical : .warning

            let month = Calendar.current.component(.month, from: Date())
            let year  = Calendar.current.component(.year,  from: Date())
            let key   = "\(budget.id)-\(threshold.rawValue)-\(year)-\(month)"
            guard !seenAlertIds.contains(key) else { continue }

            let payload = BudgetAlertPayload(
                categoryId:    budget.id,
                categoryName:  budget.categoryName,
                categoryIcon:  budget.categoryIcon,
                categoryColor: budget.categoryColor,
                spent:         budget.spent,
                limit:         budget.limit,
                currency:      budget.currency,
                alertType:     threshold,
                timestamp:     Date()
            )

            budgetAlerts.append(payload)
            seenAlertIds.insert(key)
            fireWatchAlert(payload)
        }
    }

    private func fireWatchAlert(_ payload: BudgetAlertPayload) {
        WKInterfaceDevice.current().play(payload.alertType == .exceeded ? .failure : .directionUp)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            showBudgetAlert = payload
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = state == .activated
        }
        
        // Eagerly grab any pending context once activated
        if state == .activated {
            if let data = session.receivedApplicationContext["snapshot"] as? Data {
                handleIncomingData(data)
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        handleIncomingData(messageData)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        if let data = context["snapshot"] as? Data { handleIncomingData(data) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo["budgetAlert"] as? Data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let payload = try? decoder.decode(BudgetAlertPayload.self, from: data) {
                budgetAlerts.append(payload)
                fireWatchAlert(payload)
            }
        }
    }

    private func handleIncomingData(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snap = try? decoder.decode(ZFlowSnapshot.self, from: data) {
            DispatchQueue.main.async {
                self.snapshot = snap
                SnapshotStore.shared.save(snap)
                self.checkBudgetAlerts()
            }
        }
    }

    // MARK: - Quick Add → iPhone

    func sendQuickAdd(_ item: WatchQuickAdd) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(item) else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(["quickAdd": data])
        }
        WKInterfaceDevice.current().play(.success)
    }

    func dismissAlert() { showBudgetAlert = nil }
}
