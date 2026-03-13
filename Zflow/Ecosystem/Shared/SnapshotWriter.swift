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
        primaryCurrency: String,
        scheduledPayments: [ScheduledPayment] = [],
        recurringTransactions: [RecurringTransaction] = []
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

        let monthIncome = thisMonth.filter { $0.type == "income" }.reduce(0) { sum, txn in
            sum + CurrencyConverter.convert(amount: txn.amount, from: txn.currency, to: primaryCurrency)
        }
        let monthExpense = thisMonth.filter { $0.type == "expense" }.reduce(0) { sum, txn in
            sum + CurrencyConverter.convert(amount: txn.amount, from: txn.currency, to: primaryCurrency)
        }
        let netBalance = transactions.reduce(0) { sum, txn in
            let conv = CurrencyConverter.convert(amount: txn.amount, from: txn.currency, to: primaryCurrency)
            return sum + (txn.type == "income" ? conv : -conv)
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
                .reduce(0) { sum, txn in
                    sum + CurrencyConverter.convert(amount: txn.amount, from: txn.currency, to: primaryCurrency)
                }
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

        // Snapshot categories (for Watch category picker)
        let snapshotCategories = categories.map { cat in
            SnapshotCategory(
                id:    cat.id,
                name:  cat.name,
                icon:  cat.icon ?? "circle",
                color: cat.color,
                type:  cat.type ?? "expense"
            )
        }

        // Category breakdown (expense totals this month)
        let expenseByCategory = Dictionary(grouping: thisMonth.filter { $0.type == "expense" }) { $0.categoryId ?? UUID() }
        let totalExpense = monthExpense > 0 ? monthExpense : 1.0
        let breakdown: [SnapshotCategoryBreakdown] = expenseByCategory.compactMap { (catId, txns) in
            guard let cat = catMap[catId] else { return nil }
            let total = txns.reduce(0) { $0 + $1.amount }
            return SnapshotCategoryBreakdown(
                id:      catId,
                name:    cat.name,
                icon:    cat.icon ?? "circle",
                color:   cat.color,
                total:   total,
                percent: (total / totalExpense) * 100
            )
        }
        .sorted { $0.total > $1.total }

        let snapshotScheduled = scheduledPayments.map {
            SnapshotScheduledPayment(
                id: $0.id,
                title: $0.title,
                amount: CurrencyConverter.convert(amount: $0.amount, from: $0.currency, to: primaryCurrency),
                currency: primaryCurrency,
                type: $0.type ?? "expense",
                scheduledDate: $0.scheduledDate,
                status: $0.status
            )
        }.sorted { $0.scheduledDate < $1.scheduledDate }

        // Recurring transactions (aktif olanlar, en yakın gün sırasıyla)
        let snapshotRecurring = recurringTransactions
            .filter { $0.isActive }
            .map { rt -> SnapshotRecurringTransaction in
                let cat = catMap[rt.categoryId ?? UUID()]
                return SnapshotRecurringTransaction(
                    id:              rt.id,
                    title:           rt.title,
                    expectedAmount:  rt.expectedAmount != nil ? CurrencyConverter.convert(amount: rt.expectedAmount!, from: rt.currency, to: primaryCurrency) : nil,
                    currency:        primaryCurrency,
                    transactionType: rt.transactionType,
                    dayOfMonth:      rt.dayOfMonth,
                    categoryName:    cat?.name  ?? "Other",
                    categoryIcon:    cat?.icon  ?? "circle",
                    categoryColor:   cat?.color ?? "#8E8E93",
                    isActive:        rt.isActive
                )
            }
            .sorted { $0.dayOfMonth < $1.dayOfMonth }

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
            userType:             profile?.userType    ?? "personal",
            categories:           snapshotCategories,
            categoryBreakdown:    breakdown,
            scheduledPayments:    snapshotScheduled,
            recurringTransactions: snapshotRecurring,
            accentPrimaryHex:     AppTheme.baseColorHex,
            accentSecondaryHex:   AppTheme.accentSecondary.toHex()
        )

        SnapshotStore.shared.save(snapshot)

        // Reload all WidgetKit timelines
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
