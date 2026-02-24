// ============================================================
// ZFlow — Balance Widget
// Sizes: small, medium, large, extraLarge (iPad)
// ============================================================
import WidgetKit
import SwiftUI

// MARK: - Balance Widget

struct ZFlowBalanceWidget: Widget {
    let kind = "ZFlowBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            BalanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ZFlow Balance")
        .description("Net balance and monthly summary.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Balance Widget View

struct BalanceWidgetView: View {
    let entry: ZFlowEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        case .systemLarge:  largeView
        default:            smallView
        }
    }

    // MARK: Small — net balance + trend arrow

    private var smallView: some View {
        ZStack {
            widgetBackground

            VStack(alignment: .leading, spacing: 0) {
                // Logo
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentGrad)
                    Text("ZFlow")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(accentGrad)
                    Spacer()
                }

                Spacer()

                // Balance
                Text("Net Balance")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)

                Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(entry.snapshot.netBalance >= 0 ? .primary : Color(hex: "#FF453A"))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer().frame(height: 6)

                // Month change chip
                monthChangeChip
            }
            .padding(14)
        }
    }

    // MARK: Medium — balance + income/expense + mini sparkline

    private var mediumView: some View {
        ZStack {
            widgetBackground

            HStack(spacing: 0) {
                // Left — balance
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(accentGrad)
                        Text("ZFlow")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(accentGrad)
                    }

                    Spacer()

                    Text("Net Balance")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.3)

                    Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)

                    monthChangeChip
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
                .padding(.vertical, 14)

                Divider().padding(.vertical, 14)

                // Right — income + expense
                VStack(spacing: 10) {
                    incomeExpenseRow(
                        label: "Income",
                        value: entry.snapshot.thisMonthIncome,
                        icon: "arrow.down.circle.fill",
                        color: Color(hex: "#30D158"))

                    Divider()

                    incomeExpenseRow(
                        label: "Expense",
                        value: entry.snapshot.thisMonthExpense,
                        icon: "arrow.up.circle.fill",
                        color: Color(hex: "#FF453A"))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: Large — balance + sparkline + recent 3 transactions

    private var largeView: some View {
        ZStack {
            widgetBackground

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accentGrad)
                        Text("ZFlow")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(accentGrad)
                    }
                    Spacer()
                    Text(entry.snapshot.updatedAt, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Balance hero
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Balance")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .padding(.horizontal, 16)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        monthChangeChip
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

                // Sparkline
                WeeklySparkline(values: entry.snapshot.weeklyExpenses)
                    .frame(height: 50)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                Divider().padding(.horizontal, 16)

                // Recent transactions
                VStack(spacing: 0) {
                    ForEach(Array(entry.snapshot.recentTransactions.prefix(3).enumerated()), id: \.element.id) { idx, txn in
                        WidgetTransactionRow(txn: txn, currency: entry.snapshot.currency)
                        if idx < 2 { Divider().padding(.leading, 52) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Spacer()
            }
        }
    }

    // MARK: - Sub-components

    private var monthChangeChip: some View {
        let diff = entry.snapshot.thisMonthIncome - entry.snapshot.thisMonthExpense
        let positive = diff >= 0
        return HStack(spacing: 3) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.left")
                .font(.system(size: 9, weight: .bold))
            Text(diff.formattedShort() + " " + entry.snapshot.currency)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(positive ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((positive ? Color(hex: "#30D158") : Color(hex: "#FF453A")).opacity(0.12)))
    }

    private func incomeExpenseRow(label: String, value: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value.formattedCurrencySimple(code: entry.snapshot.currency))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    // MARK: Background

    private var widgetBackground: some View {
        Color(.systemBackground)
    }

    private var accentGrad: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Weekly Sparkline

struct WeeklySparkline: View {
    let values: [Double]
    private var max: Double { values.max() ?? 1 }
    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height - 16  // reserve for labels
            let barW = w / CGFloat(values.count) - 4

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, val in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF453A").opacity(0.85), Color(hex: "#FF453A").opacity(0.4)],
                                    startPoint: .top, endPoint: .bottom))
                            .frame(
                                width: barW,
                                height: max > 0 ? Swift.max(4, h * CGFloat(val / max)) : 4)
                        Text(days[i % 7])
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Widget Transaction Row

struct WidgetTransactionRow: View {
    let txn: SnapshotTransaction
    let currency: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: txn.categoryColor).opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: txn.categoryIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: txn.categoryColor))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(txn.categoryName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                if let note = txn.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(txn.type == "income" ? "+" : "−")\(txn.amount.formattedShort()) \(txn.currency)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(txn.type == "income" ? Color(hex: "#30D158") : Color(hex: "#FF453A"))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Color(hex:) for Widget target

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
