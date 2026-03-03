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
    let scheduledPaymentId: UUID?  // ilişkili scheduled payment varsa

    enum InsightType {
        case warning, positive, info, neutral, upcoming
        var color: Color {
            switch self {
            case .warning:  .orange
            case .positive: Color(hex: "#10B981")
            case .info:     Color(hex: "#6366F1")
            case .neutral:  .secondary
            case .upcoming: Color(hex: "#F59E0B")
            }
        }
        var bgColor: Color { color.opacity(0.10) }

        var icon: String {
            switch self {
            case .warning:  "exclamationmark.triangle.fill"
            case .positive: "star.fill"
            case .info:     "lightbulb.fill"
            case .neutral:  "info.circle.fill"
            case .upcoming: "calendar.badge.clock"
            }
        }
    }

    init(icon: String, title: String, message: String, type: InsightType,
         actionLabel: String? = nil, scheduledPaymentId: UUID? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.type = type
        self.actionLabel = actionLabel
        self.scheduledPaymentId = scheduledPaymentId
    }
}

// MARK: - Engine

struct InsightsEngine {

    /// Generates rich, AI-style financial insights from transactions, budgets & scheduled payments
    static func generate(
        transactions: [Transaction],
        categories: [Category] = [],
        primaryCurrency: String,
        budgets: [UUID: Double],
        scheduledPayments: [ScheduledPayment] = []
    ) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []

        let cal   = Calendar.current
        let now   = Date()

        // ── Period filters ──────────────────────────────────────────────────
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

        func catName(_ id: UUID?) -> String {
            guard let id else { return "?" }
            return categories.first(where: { $0.id == id })?.name ?? "Diğer"
        }

        let thisExpense = thisMonth.filter { $0.type == "expense" }.reduce(0.0) { $0 + converted($1) }
        let lastExpense = lastMonth.filter { $0.type == "expense" }.reduce(0.0) { $0 + converted($1) }
        let thisIncome  = thisMonth.filter { $0.type == "income"  }.reduce(0.0) { $0 + converted($1) }

        // ── 1. Upcoming scheduled payments (next 7 days) ───────────────────
        let sevenDaysLater = cal.date(byAdding: .day, value: 7, to: now) ?? now
        let upcoming = scheduledPayments.filter {
            ($0.status == "pending" || $0.status == "ready")
            && $0.scheduledDate >= now
            && $0.scheduledDate <= sevenDaysLater
        }.sorted { $0.scheduledDate < $1.scheduledDate }

        for payment in upcoming.prefix(3) {
            let daysLeft = cal.dateComponents([.day], from: now, to: payment.scheduledDate).day ?? 0
            let dayText  = daysLeft == 0 ? "bugün" : daysLeft == 1 ? "yarın" : "\(daysLeft) gün içinde"
            let amtText  = payment.amount.formattedCurrency(code: payment.currency)
            insights.append(.init(
                icon: "calendar.badge.exclamationmark",
                title: "Yaklaşan Ödeme",
                message: "**\(payment.title)** için \(amtText) ödemeniz \(dayText) gerçekleşmesi için onay bekliyor.",
                type: .upcoming,
                actionLabel: "Kalendere Git",
                scheduledPaymentId: payment.id
            ))
        }

        // ── 2. Ready payments (due today, awaiting confirmation) ───────────
        let readyToday = scheduledPayments.filter {
            $0.status == "ready"
            && cal.isDateInToday($0.scheduledDate)
        }
        if !readyToday.isEmpty {
            let names = readyToday.prefix(2).map { $0.title }.joined(separator: ", ")
            insights.append(.init(
                icon: "bell.badge.fill",
                title: "Bugün Onay Bekliyor",
                message: "\(names) ödemeleri bugün gerçekleşmesi bekliyor. Takvimden onaylayın.",
                type: .warning,
                actionLabel: "Takvime Git"
            ))
        }

        // ── 3. Month-over-month comparison ──────────────────────────────────
        if lastExpense > 0 {
            let change = ((thisExpense - lastExpense) / lastExpense) * 100
            if change > 20 {
                insights.append(.init(
                    icon: "exclamationmark.triangle.fill",
                    title: "Harcama %\(Int(change)) Arttı",
                    message: "Bu ay harcamalarınız geçen aya göre %\(Int(change)) arttı. Son harcamalarınızı gözden geçirin.",
                    type: .warning))
            } else if change < -10 {
                insights.append(.init(
                    icon: "hand.thumbsup.fill",
                    title: "Harika Tasarruf! 🎉",
                    message: "Harcamalarınızı geçen aya göre %\(Int(abs(change))) azalttınız. Böyle devam edin!",
                    type: .positive))
            } else if abs(change) <= 5 {
                // Stable spending
                insights.append(.init(
                    icon: "equal.circle.fill",
                    title: "Dengeli Harcama",
                    message: "Bu ayki harcamalarınız geçen ayla hemen hemen aynı seviyede. Güzel bir istikrar!",
                    type: .info))
            }
        }

        // ── 4. Savings rate ──────────────────────────────────────────────────
        if thisIncome > 0 {
            let rate = ((thisIncome - thisExpense) / thisIncome) * 100
            if rate < 0 {
                insights.append(.init(
                    icon: "exclamationmark.circle.fill",
                    title: "Gelirinizi Aşıyorsunuz",
                    message: "Bu ay gelirinizden \((thisExpense - thisIncome).formattedCurrency(code: primaryCurrency)) fazla harcadınız. Gereksiz giderleri gözden geçirin.",
                    type: .warning))
            } else if rate < 10 {
                insights.append(.init(
                    icon: "chart.line.downtrend.xyaxis",
                    title: "Düşük Tasarruf Oranı",
                    message: "Gelirinizin yalnızca %\(Int(rate))'ini biriktiriyorsunuz. Hedef en az %20 olmalı.",
                    type: .warning))
            } else if rate >= 30 {
                insights.append(.init(
                    icon: "star.fill",
                    title: "Mükemmel Tasarruf! ⭐",
                    message: "Bu ay gelirinizin %\(Int(rate))'ini biriktiriyorsunuz. Finansal hedefinize yaklaşıyorsunuz!",
                    type: .positive))
            }
        }

        // ── 5. Top category spending insight (AI-style narrative) ─────────
        let expByCat = Dictionary(grouping: thisMonth.filter { $0.type == "expense" }) { $0.categoryId }

        let sortedCats = expByCat.map { (id: $0.key, total: $0.value.reduce(0.0) { $0 + converted($1) }) }
            .sorted { $0.total > $1.total }

        // Top 3 categories with detailed narrative
        for (i, item) in sortedCats.prefix(3).enumerated() {
            let catN  = catName(item.id)
            let amtTxt = item.total.formattedCurrency(code: primaryCurrency)
            let pct   = thisExpense > 0 ? Int((item.total / thisExpense) * 100) : 0

            if i == 0 && pct > 30 {
                insights.append(.init(
                    icon: "chart.bar.fill",
                    title: "En Çok: \(catN)",
                    message: "Bu ay en çok **\(catN)** kategorisinde \(amtTxt) harcadınız — toplam harcamanızın %\(pct)'i.",
                    type: .info))
            } else if i == 1 && pct > 15 {
                insights.append(.init(
                    icon: "tag.fill",
                    title: "\(catN) Kategorisi",
                    message: "**\(catN)** bu ay 2. en büyük gideriniz: \(amtTxt) (%\(pct)).",
                    type: .neutral))
            }
        }

        // ── 6. Income vs Expense comparison ──────────────────────────────────
        if thisIncome > 0 && thisExpense > 0 {
            let net = thisIncome - thisExpense
            if net > 0 {
                let savedText = net.formattedCurrency(code: primaryCurrency)
                let incText   = thisIncome.formattedCurrency(code: primaryCurrency)
                let expText   = thisExpense.formattedCurrency(code: primaryCurrency)
                insights.append(.init(
                    icon: "arrow.up.arrow.down.circle.fill",
                    title: "Gelir-Gider Özeti",
                    message: "Bu ay \(incText) gelir, \(expText) gider — net \(savedText) birikimdesiniz.",
                    type: .positive))
            }
        }

        // ── 7. End-of-month projection ───────────────────────────────────────
        let dayOfMonth  = cal.component(.day, from: now)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        if dayOfMonth > 5 && thisExpense > 0 {
            let projected = (thisExpense / Double(dayOfMonth)) * Double(daysInMonth)
            if thisIncome > 0 && projected > thisIncome * 0.95 {
                insights.append(.init(
                    icon: "calendar.badge.exclamationmark",
                    title: "Ay Sonu Uyarısı",
                    message: "Bu gidişle ay sonunda tahmini toplam harcamanız \(projected.formattedCurrency(code: primaryCurrency)) — gelirinize yakın!",
                    type: .warning))
            }
        }

        // ── 8. Budget warnings ───────────────────────────────────────────────
        for (catId, limit) in budgets {
            if let txns = expByCat[catId] {
                let spent = txns.reduce(0.0) { $0 + converted($1) }
                let ratio = spent / limit
                let cn    = catName(catId)
                if ratio >= 1.0 {
                    insights.append(.init(
                        icon: "xmark.circle.fill",
                        title: "\(cn) Bütçesi Aşıldı",
                        message: "\(cn) kategorisinde bütçenizi %\(Int((ratio - 1) * 100)) aştınız! (\(spent.formattedCurrency(code: primaryCurrency)) / \(limit.formattedCurrency(code: primaryCurrency)))",
                        type: .warning))
                } else if ratio >= 0.8 {
                    let remaining = (limit - spent).formattedCurrency(code: primaryCurrency)
                    insights.append(.init(
                        icon: "exclamationmark.triangle.fill",
                        title: "\(cn) Bütçe Uyarısı",
                        message: "\(cn) bütçenizin %\(Int(ratio * 100))'ini kullandınız. Kalan: \(remaining)",
                        type: .warning))
                }
            }
        }

        // ── 9. No data fallback ──────────────────────────────────────────────
        if thisMonth.isEmpty && upcoming.isEmpty && readyToday.isEmpty {
            insights.append(.init(
                icon: "plus.circle.fill",
                title: "Takibe Başlayın",
                message: "İlk işleminizi ekleyin ve kişiselleştirilmiş finansal yorumlarınızı görün.",
                type: .info,
                actionLabel: "İşlem Ekle"))
        } else if insights.isEmpty {
            insights.append(.init(
                icon: "checkmark.seal.fill",
                title: "Her Şey Yolunda 👍",
                message: "Bu ay finansal durumunuz sağlıklı görünüyor. Takibe devam edin!",
                type: .positive))
        }

        return insights
    }
}
