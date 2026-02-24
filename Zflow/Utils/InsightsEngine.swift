import Foundation
import SwiftUI

// MARK: - Insight Model

struct FinancialInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let type: InsightType
    let actionLabel: String?

    enum InsightType {
        case warning, positive, info, neutral
        var color: Color {
            switch self {
            case .warning:  .orange
            case .positive: Color(hex: "#10B981")
            case .info:     Color(hex: "#6366F1")
            case .neutral:  .secondary
            }
        }
        var bgColor: Color { color.opacity(0.1) }
    }

    init(icon: String, title: String, message: String, type: InsightType, actionLabel: String? = nil) {
        self.icon = icon; self.title = title; self.message = message
        self.type = type; self.actionLabel = actionLabel
    }
}

// MARK: - Engine

struct InsightsEngine {

    static func generate(
        transactions: [Transaction],
        primaryCurrency: String,
        budgets: [UUID: Double]
    ) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []

        let cal   = Calendar.current
        let now   = Date()

        let thisMonth = transactions.filter {
            guard let d = $0.date else { return false }
            return cal.isDate(d, equalTo: now, toGranularity: .month)
        }
        let lastMonthDate = cal.date(byAdding: .month, value: -1, to: now) ?? now
        let lastMonth = transactions.filter {
            guard let d = $0.date else { return false }
            return cal.isDate(d, equalTo: lastMonthDate, toGranularity: .month)
        }

        func converted(_ txn: Transaction) -> Double {
            CurrencyConverter.convert(amount: txn.amount, from: txn.currency, to: primaryCurrency)
        }

        let thisExpense = thisMonth.filter { $0.type == "expense" }.reduce(0.0) { $0 + converted($1) }
        let lastExpense = lastMonth.filter { $0.type == "expense" }.reduce(0.0) { $0 + converted($1) }
        let thisIncome  = thisMonth.filter { $0.type == "income"  }.reduce(0.0) { $0 + converted($1) }

        // 1 — Month-over-month comparison
        if lastExpense > 0 {
            let change = ((thisExpense - lastExpense) / lastExpense) * 100
            if change > 20 {
                insights.append(.init(
                    icon: "exclamationmark.triangle.fill",
                    title: "Spending Up \(String(format: "%.0f", change))%",
                    message: "Your expenses are higher than last month. Review your recent spending.",
                    type: .warning))
            } else if change < -10 {
                insights.append(.init(
                    icon: "hand.thumbsup.fill",
                    title: "Great Saving!",
                    message: "You've reduced spending by \(String(format: "%.0f", abs(change)))% vs last month. Keep it up!",
                    type: .positive))
            }
        }

        // 2 — Savings rate
        if thisIncome > 0 {
            let rate = ((thisIncome - thisExpense) / thisIncome) * 100
            if rate < 0 {
                insights.append(.init(
                    icon: "exclamationmark.circle.fill",
                    title: "Spending Exceeds Income",
                    message: "You're spending more than you earn this month. Try cutting discretionary expenses.",
                    type: .warning))
            } else if rate < 10 {
                insights.append(.init(
                    icon: "chart.line.downtrend.xyaxis",
                    title: "Low Savings Rate",
                    message: "You're saving only \(String(format: "%.0f", rate))% of income. Aim for 20%+.",
                    type: .warning))
            } else if rate >= 30 {
                insights.append(.init(
                    icon: "star.fill",
                    title: "Excellent Savings!",
                    message: "You're saving \(String(format: "%.0f", rate))% of your income this month.",
                    type: .positive))
            }
        }

        // 3 — End-of-month projection
        let dayOfMonth  = cal.component(.day, from: now)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        if dayOfMonth > 5 && thisExpense > 0 {
            let projected = (thisExpense / Double(dayOfMonth)) * Double(daysInMonth)
            if thisIncome > 0 && projected > thisIncome * 0.95 {
                insights.append(.init(
                    icon: "calendar.badge.exclamationmark",
                    title: "Month-End Alert",
                    message: "Projected spend of \(projected.formattedCurrency(code: primaryCurrency)) is near your income.",
                    type: .warning))
            }
        }

        // 4 — Dominant category
        let expByCat = Dictionary(grouping: thisMonth.filter { $0.type == "expense" }) { $0.categoryId }
        if let top = expByCat.max(by: {
            $0.value.reduce(0) { $0 + converted($1) } < $1.value.reduce(0) { $0 + converted($1) }
        }) {
            let total = top.value.reduce(0.0) { $0 + converted($1) }
            if thisExpense > 0 && (total / thisExpense) > 0.4 {
                insights.append(.init(
                    icon: "magnifyingglass.circle.fill",
                    title: "Spending Concentration",
                    message: "Over 40% of your expenses go to a single category. Diversifying may help.",
                    type: .info))
            }
        }

        // 5 — Budget warnings
        for (catId, limit) in budgets {
            if let txns = expByCat[catId] {
                let spent = txns.reduce(0.0) { $0 + converted($1) }
                let ratio = spent / limit
                if ratio >= 1.0 {
                    insights.append(.init(
                        icon: "xmark.circle.fill",
                        title: "Budget Exceeded",
                        message: "You've gone \(String(format: "%.0f", (ratio - 1) * 100))% over budget for a category!",
                        type: .warning))
                } else if ratio >= 0.8 {
                    insights.append(.init(
                        icon: "exclamationmark.triangle.fill",
                        title: "Budget Warning",
                        message: "\(String(format: "%.0f", ratio * 100))% of budget used — only \((limit - spent).formattedCurrency(code: primaryCurrency)) left.",
                        type: .warning))
                }
            }
        }

        // 6 — No data state
        if thisMonth.isEmpty {
            insights.append(.init(
                icon: "plus.circle.fill",
                title: "Start Tracking",
                message: "Add your first transaction to unlock personalized financial insights.",
                type: .info,
                actionLabel: "Add Transaction"))
        } else if insights.isEmpty {
            insights.append(.init(
                icon: "checkmark.seal.fill",
                title: "All Looking Good",
                message: "Your finances look healthy this month. Keep tracking to stay on top.",
                type: .positive))
        }

        return insights
    }
}
