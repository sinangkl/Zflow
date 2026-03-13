// ============================================================
// ZFlow — Balance Widget
// Sizes: small, medium, large, extraLarge (iPad)
// ============================================================
import WidgetKit
import SwiftUI

// MARK: - Widget Semantic Palette
// Mirrors ZColor / AppTheme from the main app.
// Widget target is isolated, so equivalent constants are defined here.

private extension Color {
    /// Income — matches ZColor.income (#50C878 Soft Emerald)
    static let wIncome     = Color(hex: "#50C878")
    /// Expense — matches ZColor.expense (#FF7F7F Soft Coral)
    static let wExpense    = Color(hex: "#FF7F7F")
    /// Brand accent — defaults to indigo (#5E5CE6) if not in snapshot
    static func wAccent(hex: String?) -> Color { Color(hex: hex ?? "#5E5CE6") }
    /// Brand accent dark — defaults to indigoDark (#7D7AFF)
    static func wAccentDark(hex: String?) -> Color { Color(hex: hex ?? "#7D7AFF") }
    /// Negative balance — Apple system red
    static let wNegative   = Color(hex: "#FF453A")
}

// MARK: - Widget Typography Helpers
// Mirrors EliteTypography from the main app.
// Uses .rounded design and matching weights for visual consistency.

private extension Font {
    /// Hero balance: thin + rounded, size varies per widget family
    static func wHeroBalance(_ size: CGFloat) -> Font {
        .system(size: size, weight: .thin, design: .rounded)
    }
    /// Brand label: black + rounded
    static func wBrand(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    /// Uppercase caption: bold + rounded
    static func wCaption(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    /// Body bold
    static func wBody(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Balance Widget

struct ZFlowBalanceWidget: Widget {
    let kind = "ZFlowBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            BalanceWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetGradientBackground(snapshot: entry.snapshot) }
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

            VStack(alignment: .leading, spacing: 4) {
                // Logo — Color.primary (white in dark / dark in light) ensures
                // readability on any theme background color
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.wBrand(11))
                        .foregroundColor(.primary)
                    Text("ZFlow")
                        .font(.wBrand(11))
                        .foregroundColor(.primary)
                    Spacer()
                }

                Spacer()

                // Balance
                Text(Localizer.shared.l("widgets.netBalance"))
                    .font(.wCaption(10))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                    .font(.wHeroBalance(24))
                    .foregroundStyle(entry.snapshot.netBalance >= 0 ? Color.primary : Color.wNegative)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Spacer().frame(height: 6)

                // Month change chip
                monthChangeChip
            }
            .padding(18) // Optimized for 158pt square
        }
    }

    // MARK: Medium — balance + income/expense + mini sparkline

    private var mediumView: some View {
        ZStack {
            widgetBackground

            HStack(spacing: 0) {
                // Left — balance
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.wBrand(12))
                            .foregroundColor(.primary)
                        Text("ZFlow")
                            .font(.wBrand(12))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Text(Localizer.shared.l("widgets.netBalance"))
                        .font(.wCaption(10))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                        .font(.wHeroBalance(28))
                        .foregroundStyle(Color.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    monthChangeChip
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.vertical, 18) // Optimized for 338pt x 158pt

                Divider().padding(.vertical, 14)

                // Right — income + expense
                VStack(spacing: 10) {
                    incomeExpenseRow(
                        label: Localizer.shared.l("dashboard.income"),
                        value: entry.snapshot.thisMonthIncome,
                        icon: "arrow.up.circle.fill",
                        color: .wIncome)

                    Divider()

                    incomeExpenseRow(
                        label: Localizer.shared.l("dashboard.expense"),
                        value: entry.snapshot.thisMonthExpense,
                        icon: "arrow.down.circle.fill",
                        color: .wExpense)
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
                            .font(.wBrand(14))
                            .foregroundColor(.primary)
                        Text("ZFlow")
                            .font(.wBrand(14))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text(entry.snapshot.updatedAt, style: .time)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                // Balance hero
                VStack(alignment: .leading, spacing: 6) {
                    Text(Localizer.shared.l("widgets.netBalance"))
                        .font(.wCaption(11))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .padding(.horizontal, 22)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                            .font(.wHeroBalance(34))
                            .foregroundStyle(Color.primary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        monthChangeChip
                    }
                    .padding(.horizontal, 22)
                }
                .padding(.vertical, 12)

                // Sparkline
                WeeklySparkline(values: entry.snapshot.weeklyExpenses)
                    .frame(height: 64)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)

                Divider().opacity(0.3).padding(.horizontal, 22)

                // Recent transactions
                VStack(spacing: 0) {
                    ForEach(Array(entry.snapshot.recentTransactions.prefix(4).enumerated()), id: \.element.id) { idx, txn in
                        WidgetTransactionRow(txn: txn, currency: entry.snapshot.currency)
                        if idx < 3 { Divider().opacity(0.2).padding(.leading, 52) }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)

                Spacer()
            }
        }
    }

    // MARK: - Sub-components

    private var monthChangeChip: some View {
        let diff = entry.snapshot.thisMonthIncome - entry.snapshot.thisMonthExpense
        let positive = diff >= 0
        let chipColor: Color = positive ? .wIncome : .wExpense
        return HStack(spacing: 3) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.left")
                .font(.wCaption(9))
            Text(diff.formattedShort() + " " + entry.snapshot.currency)
                .font(.wCaption(10))
        }
        .foregroundStyle(chipColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(chipColor.opacity(0.12)))
    }

    private func incomeExpenseRow(label: String, value: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.wBody(13))
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.wCaption(10))
                    .foregroundStyle(.secondary)
                Text(value.formattedCurrencySimple(code: entry.snapshot.currency))
                    .font(.wBody(13))
                    .foregroundStyle(Color.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    // MARK: Background

    private var widgetBackground: some View {
        WidgetGlassBackground()
            .ignoresSafeArea()
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
                                    colors: [Color.wExpense.opacity(0.9), Color.wExpense.opacity(0.35)],
                                    startPoint: .top, endPoint: .bottom))
                            .frame(
                                width: barW,
                                height: max > 0 ? Swift.max(4, h * CGFloat(val / max)) : 4)
                        Text(days[i % 7])
                            .font(.wCaption(8))
                            .foregroundStyle(.secondary)
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
                Circle()
                    .fill(Color(hex: txn.categoryColor).opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: txn.categoryIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: txn.categoryColor))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(Localizer.shared.category(txn.categoryName))
                    .font(.wBody(12))
                    .foregroundStyle(Color.primary)
                if let note = txn.note, !note.isEmpty {
                    Text(note)
                        .font(.wCaption(10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(txn.type == "income" ? "+" : "−")\(txn.amount.formattedShort()) \(txn.currency)")
                .font(.wBody(12))
                .foregroundStyle(txn.type == "income" ? Color.wIncome : Color.wExpense)
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
