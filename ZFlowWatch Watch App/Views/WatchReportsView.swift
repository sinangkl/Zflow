// ============================================================
// ZFlow Watch — Reports Summary View
// Shows income/expense/net, category breakdown, weekly trend
// ============================================================
import SwiftUI
import WatchKit
import Charts

struct WatchReportsView: View {
    @EnvironmentObject var store: WatchStore

    private var snap: ZFlowSnapshot { store.snapshot }
    private var net: Double { snap.thisMonthIncome - snap.thisMonthExpense }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Monthly summary card
                monthlySummary

                // Weekly sparkline
                weeklySparkline

                // Category breakdown
                if !snap.categoryBreakdown.isEmpty {
                    categoryBreakdownSection
                }

                // Scheduled payments
                if !snap.scheduledPayments.isEmpty {
                    upcomingPaymentsSection
                }

                // Recent transactions
                if !snap.recentTransactions.isEmpty {
                    recentSection
                }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(Localizer.shared.l("reports.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Monthly Summary

    private var monthlySummary: some View {
        VStack(spacing: 12) {
            // Net
            VStack(spacing: 4) {
                Text(Localizer.shared.l("reports.thisMonth"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(net.formattedCurrencySimple(code: snap.currency))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(net >= 0 ? wColor("#50C878") : wColor("#FF7F7F"))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            // Income / Expense row
            HStack(spacing: 0) {
                summaryFigure(
                    label: Localizer.shared.l("dashboard.income"),
                    value: snap.thisMonthIncome,
                    icon: "arrow.up.circle.fill",
                    color: wColor("#50C878"))
                
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 28)
                
                summaryFigure(
                    label: Localizer.shared.l("dashboard.expense"),
                    value: snap.thisMonthExpense,
                    icon: "arrow.down.circle.fill",
                    color: wColor("#FF7F7F"))
            }
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func summaryFigure(label: String, value: Double, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value.formattedShort())
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var weeklySparkline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizer.shared.l("reports.weeklyExpenses"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)

            Chart {
                ForEach(Array(snap.weeklyExpenses.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Amount", value)
                    )
                    .foregroundStyle(wExpense)
                    .interpolationMethod(.catmullRom)
                    .symbol(by: .value("Day", index))

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Amount", value)
                    )
                    .foregroundStyle(LinearGradient(colors: [wExpense.opacity(0.3), wExpense.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 50)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizer.shared.l("reports.topCategories"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)

            ForEach(snap.categoryBreakdown.prefix(5)) { item in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(wColor(item.color).opacity(0.18))
                            .frame(width: 28, height: 28)
                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(wColor(item.color))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localizer.shared.category(item.name))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(wColor(item.color))
                                    .frame(width: geo.size.width * CGFloat(item.percent / 100), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(item.total.formattedShort())
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text("\(Int(item.percent))%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Upcoming Payments

    private var upcomingPaymentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizer.shared.l("watch.upcomingPayments"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)

            let upcoming = snap.scheduledPayments.filter {
                $0.status == "pending" || $0.status == "ready"
            }.sorted { $0.scheduledDate < $1.scheduledDate }.prefix(4)

            if upcoming.isEmpty {
                Text(Localizer.shared.l("watch.noUpcomingPayments"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(upcoming) { payment in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(wColor(payment.type == "income" ? "#50C878" : "#FF7F7F").opacity(0.18))
                                .frame(width: 26, height: 26)
                            Image(systemName: payment.status == "ready" ? "exclamationmark.circle.fill" : "calendar.badge.clock")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(wColor(payment.type == "income" ? "#50C878" : "#FF7F7F"))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(payment.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(payment.scheduledDate, style: .date)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(payment.type == "income" ? "+" : "\u{2212}")\(payment.amount.formattedShort())")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(payment.type == "income" ? wColor("#50C878") : wColor("#FF7F7F"))
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Recent Transactions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizer.shared.l("dashboard.recent"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)

            ForEach(snap.recentTransactions.prefix(4)) { txn in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(wColor(txn.categoryColor).opacity(0.18))
                            .frame(width: 26, height: 26)
                        Image(systemName: txn.categoryIcon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(wColor(txn.categoryColor))
                    }

                    Text(Localizer.shared.category(txn.categoryName))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(txn.type == "income" ? "+" : "\u{2212}")\(txn.amount.formattedShort())")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(txn.type == "income" ? wColor("#50C878") : wColor("#FF7F7F"))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
