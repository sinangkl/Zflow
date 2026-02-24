import SwiftUI
import Charts

struct ReportsView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.colorScheme) var scheme

    @State private var selectedPeriod: Period  = .month
    @State private var selectedType: TransactionType = .expense

    enum Period: String, CaseIterable {
        case week = "7D", month = "30D", quarter = "90D", year = "1Y"
        var days: Int {
            switch self { case .week: 7; case .month: 30; case .quarter: 90; case .year: 365 }
        }
    }

    private var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date()) ?? Date()
    }

    private var filteredTotal: Double {
        let txns = transactionsFiltered(type: selectedType, from: startDate)
        return txns.reduce(0) { $0 + transactionVM.convert($1) }
    }

    private var breakdown: [(category: Category?, total: Double, percent: Double)] {
        transactionVM.categoryBreakdown(type: selectedType.rawValue, from: startDate)
    }

    private var dailyData: [(date: Date, total: Double)] {
        transactionVM.dailyTotals(type: selectedType.rawValue, from: startDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Controls
                        controlRow

                        // Total hero
                        totalHero

                        // Trend chart
                        if !dailyData.isEmpty { trendCard }

                        // Donut
                        if !breakdown.isEmpty { donutCard }

                        // Top categories
                        if !breakdown.isEmpty { topCategoriesCard }

                        // Full list
                        fullBreakdownCard

                        // Comparison
                        comparisonCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        VStack(spacing: 10) {
            // Period selector
            HStack(spacing: 6) {
                ForEach(Period.allCases, id: \.self) { p in
                    Button {
                        withAnimation(.spring(duration: 0.3)) { selectedPeriod = p }
                        Haptic.selection()
                    } label: {
                        Text(p.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Group {
                                    if selectedPeriod == p {
                                        RoundedRectangle(cornerRadius: 10).fill(AppTheme.accentGradient)
                                    } else {
                                        RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemGroupedBackground))
                                    }
                                }
                            )
                            .foregroundColor(selectedPeriod == p ? .white : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))

            // Type toggle
            HStack(spacing: 6) {
                typeToggleButton(.income,  "Income",  ZColor.income)
                typeToggleButton(.expense, "Expense", ZColor.expense)
            }
        }
    }

    private func typeToggleButton(_ type: TransactionType, _ label: String, _ color: Color) -> some View {
        let sel = selectedType == type
        return Button {
            withAnimation(.spring(duration: 0.3)) { selectedType = type }
            Haptic.selection()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(sel ? color : color.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(sel ? color.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .foregroundColor(sel ? color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? color.opacity(0.4) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Total Hero

    private var totalHero: some View {
        GradientCard(
            gradient: selectedType == .income ? AppTheme.income : AppTheme.expense,
            cornerRadius: 20) {
            VStack(spacing: 8) {
                Text("Total \(selectedType.displayName)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                Text(filteredTotal.formattedCurrency(code: transactionVM.primaryCurrency))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text("\(transactionsFiltered(type: selectedType, from: startDate).count) transactions · \(selectedPeriod.rawValue)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Trend Line Chart

    private var trendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Daily Trend")
                    .font(.system(size: 16, weight: .bold))

                let color: Color = selectedType == .income ? ZColor.income : ZColor.expense

                Chart(dailyData, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Amount", item.total))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Amount", item.total))
                    .foregroundStyle(color.opacity(0.1))

                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Amount", item.total))
                    .foregroundStyle(color)
                    .symbolSize(20)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(
                        by: selectedPeriod == .week ? .day : .month)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                        AxisValueLabel(
                            format: selectedPeriod == .week
                                ? .dateTime.weekday(.abbreviated)
                                : .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let d = val.as(Double.self) {
                                Text(d.formattedShort())
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Donut Chart

    private var donutCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Distribution").font(.system(size: 16, weight: .bold))

                ZStack {
                    Chart(Array(breakdown.enumerated()), id: \.offset) { idx, item in
                        SectorMark(
                            angle: .value("Amount", item.total),
                            innerRadius: .ratio(0.62),
                            angularInset: 2.5)
                        .foregroundStyle(Color(hex: item.category?.color ?? "#94A3B8"))
                        .cornerRadius(5)
                    }
                    .frame(height: 220)

                    VStack(spacing: 4) {
                        Text(filteredTotal.formattedShort())
                            .font(.system(size: 26, weight: .black))
                        Text(transactionVM.primaryCurrency)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(breakdown.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: item.category?.color ?? "#94A3B8"))
                                .frame(width: 10, height: 10)
                            Text(item.category?.name ?? "Other")
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(item.percent))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Top Categories

    private var topCategoriesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Top Categories").font(.system(size: 16, weight: .bold))

                ForEach(Array(breakdown.prefix(5).enumerated()), id: \.offset) { idx, item in
                    let c = Color(hex: item.category?.color ?? "#94A3B8")
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            // Rank badge
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(c))

                            HStack(spacing: 8) {
                                if let icon = item.category?.icon {
                                    Image(systemName: icon)
                                        .font(.system(size: 13))
                                        .foregroundColor(c)
                                }
                                Text(item.category?.name ?? "Uncategorized")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(item.total.formattedCurrency(code: transactionVM.primaryCurrency))
                                    .font(.system(size: 14, weight: .bold))
                                Text("\(Int(item.percent))%")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        BudgetProgressBar(spent: item.total, limit: filteredTotal / (item.percent / 100),
                                          color: c, height: 6)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Full Breakdown

    private var fullBreakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("All Categories").font(.system(size: 16, weight: .bold))

                if breakdown.isEmpty {
                    Text("No data for this period.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(breakdown.enumerated()), id: \.offset) { _, item in
                        let c = Color(hex: item.category?.color ?? "#94A3B8")
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(c.opacity(0.15)).frame(width: 38, height: 38)
                                Image(systemName: item.category?.icon ?? "questionmark.circle")
                                    .font(.system(size: 14)).foregroundColor(c)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.category?.name ?? "Other")
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                    Text(item.total.formattedCurrency(code: transactionVM.primaryCurrency))
                                        .font(.system(size: 14, weight: .bold))
                                }
                                BudgetProgressBar(spent: item.percent, limit: 100, color: c, height: 5)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Comparison Card

    private var comparisonCard: some View {
        let thisMonth = transactionVM.thisMonthExpense
        let lastMonth = transactionVM.lastMonthExpense
        let diff      = thisMonth - lastMonth

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Month Comparison").font(.system(size: 16, weight: .bold))

                HStack(spacing: 20) {
                    comparisonItem("This Month", value: thisMonth, color: ZColor.expense)
                    Divider().frame(height: 50)
                    comparisonItem("Last Month", value: lastMonth, color: .secondary)
                }

                if lastMonth > 0 {
                    let pct = (diff / lastMonth) * 100
                    HStack(spacing: 6) {
                        Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.left")
                        Text("\(pct >= 0 ? "+" : "")\(String(format: "%.1f", pct))% vs last month")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(pct >= 0 ? ZColor.expense : ZColor.income)
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
    }

    private func comparisonItem(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Text(value.formattedCurrency(code: transactionVM.primaryCurrency))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helper

    private func transactionsFiltered(type: TransactionType, from start: Date) -> [Transaction] {
        transactionVM.transactions.filter {
            guard let d = $0.date else { return false }
            return d >= start && $0.type == type.rawValue
        }
    }
}
