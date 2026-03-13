//
//  TipCardView.swift
//  Zflow
//
//  Geçen ay vs bu ay harcama karşılaştırması.
//  Kategori bazında veya toplam gider trend kartı.
//  Örn: "Geçen ay faturanız 650 ₺, bu ay 800 ₺ (+%23)"
//

import SwiftUI

struct TipCardView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel

    /// Belirli bir kategori için göster (nil = toplam gider)
    var categoryId: UUID? = nil
    var categoryName: String? = nil
    var categoryIcon: String? = nil
    var categoryColor: Color? = nil

    @Environment(\.colorScheme) private var scheme

    private var thisMonthExpense: Double {
        if let catId = categoryId {
            return transactionVM.categoryExpenseThisMonth(for: catId)
        }
        return transactionVM.thisMonthExpense
    }

    private var lastMonthExpense: Double {
        if let catId = categoryId {
            return transactionVM.categoryExpenseLastMonth(for: catId)
        }
        return transactionVM.lastMonthExpense
    }

    private var changePercent: Double? {
        guard lastMonthExpense > 0 else { return nil }
        return ((thisMonthExpense - lastMonthExpense) / lastMonthExpense) * 100
    }

    private var isIncrease: Bool { (changePercent ?? 0) > 0 }
    private var trendColor: Color { isIncrease ? ZColor.expense : ZColor.income }
    private var accentColor: Color { categoryColor ?? AppTheme.baseColor }

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: categoryIcon ?? "lightbulb.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(categoryName ?? Localizer.shared.l("dashboard.expense"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(Localizer.shared.l("tip.monthlyComparison"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Trend badge
                    if let pct = changePercent {
                        HStack(spacing: 3) {
                            Image(systemName: isIncrease ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(String(format: "%%%.0f", abs(pct)))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(trendColor.opacity(0.15)))
                        .foregroundColor(trendColor)
                    }
                }

                // Amount comparison
                HStack(spacing: 16) {
                    // Last month
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localizer.shared.l("tip.lastMonth"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(lastMonthExpense.formattedCurrencySimple(code: transactionVM.primaryCurrency))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))

                    // This month
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localizer.shared.l("tip.thisMonth"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(thisMonthExpense.formattedCurrencySimple(code: transactionVM.primaryCurrency))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(isIncrease ? trendColor : .primary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Progress comparison bar
                GeometryReader { geo in
                    let maxAmount = max(thisMonthExpense, lastMonthExpense, 1)
                    ZStack(alignment: .leading) {
                        // Last month (background bar)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 6)

                        // Last month actual
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(
                                width: geo.size.width * CGFloat(lastMonthExpense / maxAmount),
                                height: 6
                            )

                        // This month overlay
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, trendColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * CGFloat(thisMonthExpense / maxAmount),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                // Tip text
                if let pct = changePercent {
                    let direction = isIncrease
                        ? Localizer.shared.l("tip.increased")
                        : Localizer.shared.l("tip.decreased")
                    Text("\(categoryName ?? Localizer.shared.l("dashboard.expense")) \(direction) %\(String(format: "%.0f", abs(pct)))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(trendColor)
                        .padding(.top, 2)
                } else if lastMonthExpense == 0 {
                    Text(Localizer.shared.l("tip.noLastMonth"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
    }
}
