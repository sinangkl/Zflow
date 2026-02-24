// ============================================================
// ZFlow — Snapshot Writer
// Ana app'ten çağrılır, her transaction değişiminde günceller
// Target: ZFlow (main app only)
// ============================================================
import Foundation
import WidgetKit

// MARK: - SnapshotWriter
// TransactionViewModel + BudgetManager verilerini AppGroup'a yazar.
// Çağrı: await SnapshotWriter.write(from: transactionVM, budgets: budgetManager)

struct SnapshotWriter {

    static func write(
        transactions:  [Transaction],
        categories:    [Category],
        budgets:       [UUID: Double],
        profile:       Profile?,
        primaryCurrency: String
    ) {
        // Helper
        let catMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        // Recent transactions (max 8)
        let recent = transactions
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .prefix(8)
            .map { txn -> SnapshotTransaction in
                let cat = catMap[txn.categoryId ?? UUID()]
                return SnapshotTransaction(
                    id:            txn.id,
                    amount:        txn.amount,
                    currency:      txn.currency,
                    type:          txn.type ?? "expense",
                    categoryName:  cat?.name  ?? "Other",
                    categoryIcon:  cat?.icon  ?? "circle",
                    categoryColor: cat?.color ?? "#8E8E93",
                    note:          txn.note,
                    date:          txn.date   ?? Date()
                )
            }

        // This month income / expense
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let thisMonth  = transactions.filter { ($0.date ?? .distantPast) >= monthStart }

        let monthIncome  = thisMonth.filter { $0.type == "income"  }.reduce(0) { $0 + $1.amount }
        let monthExpense = thisMonth.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
        let netBalance   = transactions.reduce(0) { t, txn in
            t + (txn.type == "income" ? txn.amount : -txn.amount)
        }

        // Weekly sparkline (Mon → today, expense)
        var weeklyExpenses = Array(repeating: 0.0, count: 7)
        for txn in transactions where txn.type == "expense" {
            guard let d = txn.date else { continue }
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: now)).day ?? -1
            if days >= 0 && days < 7 {
                weeklyExpenses[6 - days] += txn.amount
            }
        }

        // Budget statuses (only categories with a budget set)
        let budgetStatuses: [SnapshotBudget] = budgets.compactMap { (catId, limit) in
            guard let cat = catMap[catId] else { return nil }
            let spent = thisMonth
                .filter { $0.type == "expense" && $0.categoryId == catId }
                .reduce(0) { $0 + $1.amount }
            return SnapshotBudget(
                id:            catId,
                categoryName:  cat.name,
                categoryIcon:  cat.icon  ?? "circle",
                categoryColor: cat.color,
                limit:         limit,
                spent:         spent,
                currency:      primaryCurrency
            )
        }
        .sorted { $0.ratio > $1.ratio }   // En kritik önce

        let snapshot = ZFlowSnapshot(
            netBalance:           netBalance,
            thisMonthIncome:      monthIncome,
            thisMonthExpense:     monthExpense,
            currency:             primaryCurrency,
            recentTransactions:   Array(recent),
            budgetStatuses:       budgetStatuses,
            weeklyExpenses:       weeklyExpenses,
            updatedAt:            now,
            userDisplayName:      profile?.displayName ?? "ZFlow",
            userType:             profile?.userType    ?? "personal"
        )

        SnapshotStore.shared.save(snapshot)

        // Reload all WidgetKit timelines
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
