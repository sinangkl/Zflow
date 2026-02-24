// ============================================================
// ZFlowWidgets — Main Widget Bundle
// Target: ZFlowWidgets (WidgetKit Extension)
// Xcode: File → New Target → Widget Extension → "ZFlowWidgets"
// ============================================================
import WidgetKit
import SwiftUI

// MARK: - Widget Bundle (tüm widget'ları kayıt eder)

@main
struct ZFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZFlowBalanceWidget()
        ZFlowBudgetWidget()
        ZFlowTransactionsWidget()
        ZFlowLockScreenWidget()
        ZFlowStandbyWidget()
    }
}

// MARK: - Timeline Entry

struct ZFlowEntry: TimelineEntry {
    var date: Date
    var snapshot: ZFlowSnapshot
}

// MARK: - Provider (tüm widget'lar paylaşır)

struct ZFlowProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZFlowEntry {
        ZFlowEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZFlowEntry) -> Void) {
        completion(ZFlowEntry(date: .now, snapshot: SnapshotStore.shared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZFlowEntry>) -> Void) {
        let snap = SnapshotStore.shared.load()
        let entry = ZFlowEntry(date: .now, snapshot: snap)
        // Her 30 dakikada bir yenile — transaction değişiminde WidgetCenter.reloadAllTimelines() çağrılır
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Placeholder Snapshot

extension ZFlowSnapshot {
    static var placeholder: ZFlowSnapshot {
        ZFlowSnapshot(
            netBalance:       12_840.0,
            thisMonthIncome:  18_500.0,
            thisMonthExpense:  5_660.0,
            currency:         "TRY",
            recentTransactions: [
                SnapshotTransaction(
                    id: UUID(), amount: 450, currency: "TRY",
                    type: "expense", categoryName: "Groceries",
                    categoryIcon: "cart.fill", categoryColor: "#FB923C",
                    note: "Migros", date: .now),
                SnapshotTransaction(
                    id: UUID(), amount: 18500, currency: "TRY",
                    type: "income", categoryName: "Salary",
                    categoryIcon: "banknote.fill", categoryColor: "#34D399",
                    note: nil, date: .now),
            ],
            budgetStatuses: [
                SnapshotBudget(
                    id: UUID(), categoryName: "Groceries",
                    categoryIcon: "cart.fill", categoryColor: "#FB923C",
                    limit: 3000, spent: 2700, currency: "TRY"),
                SnapshotBudget(
                    id: UUID(), categoryName: "Dining Out",
                    categoryIcon: "fork.knife", categoryColor: "#FB7185",
                    limit: 1500, spent: 820, currency: "TRY"),
            ],
            weeklyExpenses: [240, 380, 120, 560, 290, 450, 180],
            updatedAt: .now,
            userDisplayName: "ZFlow",
            userType: "personal")
    }
}
