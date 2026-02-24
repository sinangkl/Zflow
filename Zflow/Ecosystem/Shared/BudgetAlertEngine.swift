// ============================================================
// ZFlow — Budget Alert Engine
// Ana app + Watch + Notification Extension tarafından kullanılır
// ============================================================
import Foundation
import UserNotifications

// MARK: - BudgetAlertEngine

final class BudgetAlertEngine {
    static let shared = BudgetAlertEngine()
    private init() {}

    // Önceki uyarı durumunu takip eder (aynı uyarıyı tekrar gönderme)
    private let seenKey = "zflow.budgetAlerts.seen"
    private var seen: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: seenKey) }
    }

    // MARK: - Evaluate
    // Her snapshot güncellemesinde çağrılır.
    // Yeni eşik geçildiyse UNNotification gönderir.

    func evaluate(budgets: [SnapshotBudget]) {
        for budget in budgets {
            checkAndFire(budget: budget, threshold: 0.80, type: .warning)
            checkAndFire(budget: budget, threshold: 0.95, type: .critical)
            checkAndFire(budget: budget, threshold: 1.00, type: .exceeded)
        }
    }

    private func checkAndFire(
        budget: SnapshotBudget,
        threshold: Double,
        type: BudgetAlertPayload.AlertType
    ) {
        guard budget.ratio >= threshold else { return }

        // Unique key: category + threshold + ay
        let month = Calendar.current.component(.month, from: Date())
        let year  = Calendar.current.component(.year,  from: Date())
        let key   = "\(budget.id.uuidString)-\(type.rawValue)-\(year)-\(month)"
        guard !seen.contains(key) else { return }

        let payload = BudgetAlertPayload(
            categoryId:    budget.id,
            categoryName:  budget.categoryName,
            categoryIcon:  budget.categoryIcon,
            categoryColor: budget.categoryColor,
            spent:         budget.spent,
            limit:         budget.limit,
            currency:      budget.currency,
            alertType:     type,
            timestamp:     Date()
        )

        scheduleNotification(payload)
        seen.insert(key)

        // Watch'a da gönder (WatchConnectivity üzerinden — WatchConnector handle eder)
        NotificationCenter.default.post(
            name: .zflowBudgetAlert,
            object: payload)
    }

    // MARK: - Reset (Yeni ay başında)
    func resetMonthly() {
        let month = Calendar.current.component(.month, from: Date())
        let year  = Calendar.current.component(.year,  from: Date())
        let prefix = "-\(year)-\(month)"
        seen = seen.filter { !$0.hasSuffix(prefix) }
    }

    // MARK: - UNUserNotification

    private func scheduleNotification(_ payload: BudgetAlertPayload) {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body  = payload.body
        content.sound = payload.alertType == .exceeded ? .defaultCritical : .default
        content.categoryIdentifier = "BUDGET_ALERT"
        content.threadIdentifier   = "budget-\(payload.categoryId)"

        // User info for deep link
        content.userInfo = [
            "categoryId": payload.categoryId.uuidString,
            "alertType":  payload.alertType.rawValue,
            "screen":     "budgets"
        ]

        // Badge
        content.interruptionLevel = payload.alertType == .exceeded ? .critical : .timeSensitive

        // Rich attachment icon (SF Symbol name stored for display)
        if #available(iOS 16.0, *) {
            let categoryIcon = payload.categoryIcon
            content.userInfo["categoryIcon"]  = categoryIcon
            content.userInfo["categoryColor"] = payload.categoryColor
        }

        let request = UNNotificationRequest(
            identifier: "budget-\(payload.categoryId)-\(payload.alertType.rawValue)",
            content: content,
            trigger: nil)   // immediate

        UNUserNotificationCenter.current().add(request) { err in
            if let err { print("ZFlow Notification error: \(err)") }
        }
    }

    // MARK: - Permission Request
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
        } catch {
            return false
        }
    }

    // MARK: - Register Notification Categories (call at app launch)
    static func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_BUDGET",
            title: "View Budget",
            options: [.foreground])

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive])

        let category = UNNotificationCategory(
            identifier: "BUDGET_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction])

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let zflowBudgetAlert    = Notification.Name("com.zflow.budgetAlert")
    static let zflowSnapshotUpdate = Notification.Name("com.zflow.snapshotUpdate")
}
