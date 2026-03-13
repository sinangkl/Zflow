// ============================================================
// ZFlow — Live Activity Manager
// Target: Zflow (main app)
// ActivityKit kullanarak Dynamic Island + Lock Screen Live Activity yönetir.
// iOS 16.1+  |  ActivityKit
// ============================================================
import ActivityKit
import Foundation
import Combine

// MARK: - Live Activity Attributes
// Widget Extension views bu struct'ı referans alır.

struct ZFlowActivityAttributes: ActivityAttributes {
    public var userDisplayName: String
    public var currency: String

    public struct ContentState: Codable, Hashable {
        var netBalance: Double
        var thisMonthExpense: Double
        var thisMonthIncome:  Double
        var lastTransactionAmount: Double?
        var lastTransactionType:   String?
        var lastTransactionCategory: String?
        var lastTransactionIcon:   String?
        var alertBudgetName:       String?
        var alertBudgetPercent:    Int?
        var alertBudgetColor:      String?    // hex
        var accentPrimaryHex:      String?    // hex
        var accentSecondaryHex:    String?    // hex
        var updatedAt: Date
    }
}

// MARK: - Live Activity Manager

final class ZFlowLiveActivityManager {
    static let shared = ZFlowLiveActivityManager()
    private var currentActivity: Activity<ZFlowActivityAttributes>?

    private init() {}

    // MARK: - Start

    func start(snapshot: ZFlowSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attrs = ZFlowActivityAttributes(
            userDisplayName: snapshot.userDisplayName,
            currency: snapshot.currency)

        let state = contentState(from: snapshot)

        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: .now))

        do {
            currentActivity = try Activity.request(
                attributes: attrs,
                content: content,
                pushType: nil)
        } catch {
            print("ZFlow LiveActivity start error: \(error)")
        }
    }

    // MARK: - Update

    func update(snapshot: ZFlowSnapshot, alert: BudgetAlertPayload? = nil) {
        let state = contentState(from: snapshot, alert: alert)
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: .now))

        Task {
            await currentActivity?.update(content)
        }
    }

    // MARK: - End

    func end() {
        Task {
            guard let activity = currentActivity else { return }
            await activity.end(ActivityContent(
                state: activity.content.state,
                staleDate: .now), dismissalPolicy: .after(.now + 5))
            currentActivity = nil
        }
    }

    // MARK: - Private Helper

    private func contentState(
        from snapshot: ZFlowSnapshot,
        alert: BudgetAlertPayload? = nil
    ) -> ZFlowActivityAttributes.ContentState {
        let last = snapshot.recentTransactions.first

        return ZFlowActivityAttributes.ContentState(
            netBalance:              snapshot.netBalance,
            thisMonthExpense:        snapshot.thisMonthExpense,
            thisMonthIncome:         snapshot.thisMonthIncome,
            lastTransactionAmount:   last?.amount,
            lastTransactionType:     last?.type,
            lastTransactionCategory: last?.categoryName,
            lastTransactionIcon:     last?.categoryIcon,
            alertBudgetName:         alert?.categoryName,
            alertBudgetPercent:      alert.map { Int(($0.spent / $0.limit) * 100) },
            alertBudgetColor:        alert.map { ZFlowBudgetColor(
                rawValue: $0.alertType == .exceeded ? "exceeded"
                        : $0.alertType == .critical ? "critical" : "warning"
            )?.hex ?? "#FF9F0A" },
            accentPrimaryHex:        snapshot.accentPrimaryHex,
            accentSecondaryHex:      snapshot.accentSecondaryHex,
            updatedAt: .now)
    }
}
