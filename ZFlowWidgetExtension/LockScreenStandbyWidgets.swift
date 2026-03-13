// ============================================================
// ZFlow — Lock Screen + Standby Widgets
// Lock Screen: iOS 16+  |  StandBy: iOS 17+
// ============================================================
import WidgetKit
import SwiftUI

// MARK: - Lock Screen Widget (accessoryCircular + accessoryRectangular + accessoryInline)

struct ZFlowLockScreenWidget: Widget {
    let kind = "ZFlowLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget) // system-controlled for lock screen
        }
        .configurationDisplayName("ZFlow Lock Screen")
        .description("Balance and budget on your Lock Screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct LockScreenWidgetView: View {
    let entry: ZFlowEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:   circularView
        case .accessoryRectangular: rectangularView
        case .accessoryInline:     inlineView
        default:                   inlineView
        }
    }

    // Circular — budget ring (most critical budget) or balance
    private var circularView: some View {
        ZStack {
            if let topBudget = entry.snapshot.budgetStatuses.first {
                // Budget ring
                let ratio = CGFloat(min(topBudget.ratio, 1.0))
                let color = Color(hex: topBudget.statusColor.hex)
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(0.2), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -1) {
                        Image(systemName: topBudget.categoryIcon)
                            .font(.system(size: 13, weight: .bold))
                        Text("\(topBudget.percentage)%")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                }
            } else {
                // No budgets — show net balance
                VStack(spacing: 0) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .bold))
                    Text(entry.snapshot.netBalance.formattedShort())
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
            }
        }
        .padding(2) // Extra breathable padding for 64pt circle
        .widgetAccentable()
    }

    // Rectangular — balance + income/expense
    private var rectangularView: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18, weight: .bold))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(
                        entry.snapshot.thisMonthIncome.formattedShort(),
                        systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#50C878"))

                    Label(
                        entry.snapshot.thisMonthExpense.formattedShort(),
                        systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#FF7F7F"))
                }
            }
        }
        .padding(.horizontal, 4) // Optimized for 156x64pt
    }

    // Inline — one line summary
    private var inlineView: some View {
        let balance = entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency)
        return Label(balance, systemImage: "chart.line.uptrend.xyaxis")
            .font(.system(size: 12, weight: .bold))
            .widgetAccentable()
    }
}

// MARK: - Transactions List Widget (medium + large)

struct ZFlowTransactionsWidget: Widget {
    let kind = "ZFlowTransactionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            TransactionsWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetGradientBackground(snapshot: entry.snapshot) }
        }
        .configurationDisplayName("ZFlow Recent")
        .description("Your most recent transactions.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct TransactionsWidgetView: View {
    let entry: ZFlowEntry
    @Environment(\.widgetFamily) var family

    private var count: Int { family == .systemLarge ? 5 : 3 }

    var body: some View {
        ZStack {
            WidgetGlassBackground()
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                        Text("ZFlow")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text(NSLocalizedString("widget.recentTransactions", comment: "Recent Transactions"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)

                if family == .systemLarge {
                    // Balance summary bar
                    HStack(spacing: 16) {
                        balancePill(
                            label: NSLocalizedString("dashboard.income", comment: ""),
                            value: entry.snapshot.thisMonthIncome,
                            color: Color(hex: "#50C878"))
                        balancePill(
                            label: NSLocalizedString("dashboard.expense", comment: ""),
                            value: entry.snapshot.thisMonthExpense,
                            color: Color(hex: "#FF7F7F"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }

                Divider().padding(.horizontal, 14)

                if entry.snapshot.recentTransactions.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "tray")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("dashboard.noTransactions", comment: "No transactions yet"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entry.snapshot.recentTransactions.prefix(count).enumerated()), id: \.element.id) { idx, txn in
                            Link(destination: URL(string: "zflow://transaction/\(txn.id)")!) {
                                WidgetTransactionRow(txn: txn, currency: entry.snapshot.currency)
                            }
                            if idx < count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }

                Spacer()
            }
        }
    }

    private func balancePill(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value.formattedCurrencySimple(code: entry.snapshot.currency))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
        }
    }

}

// MARK: - StandBy Widget (iOS 17+ fullscreen always-on)

struct ZFlowStandbyWidget: Widget {
    let kind = "ZFlowStandbyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            StandbyWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.black }
        }
        .configurationDisplayName("ZFlow StandBy")
        .description("Full-screen financial overview in StandBy mode.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}

// MARK: - Design tokens

// sbAccent / sbAccent2 removed — now dynamic per snapshot (see StandbyWidgetView computed props)
private let sbGreen      = Color(hex: "#34D399")
private let sbRed        = Color(hex: "#FF7F7F")
private let sbCardFill   = Color.white.opacity(0.06)
private let sbBorder     = Color.white.opacity(0.10)
private let sbText       = Color.white
private let sbTextSec    = Color.white.opacity(0.55)

// MARK: - Main View

struct StandbyWidgetView: View {
    let entry: ZFlowEntry
    @Environment(\.widgetFamily) var family

    private var snap: ZFlowSnapshot { entry.snapshot }
    private var net: Double { snap.netBalance }
    private var netPositive: Bool { net >= 0 }
    private var accentPrimary: Color { Color(hex: snap.accentPrimaryHex ?? "#5E5CE6") }
    private var accentSecondary: Color { Color(hex: snap.accentSecondaryHex ?? "#7D7AFF") }
    private var savingsRate: Int {
        guard snap.thisMonthIncome > 0 else { return 0 }
        return max(0, Int(((snap.thisMonthIncome - snap.thisMonthExpense) / snap.thisMonthIncome) * 100))
    }

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────
            background

            // ── Content ─────────────────────────────────
            if family == .systemExtraLarge {
                extraLargeLayout
            } else {
                largeLayout
            }
        }
    }

    // MARK: - Extra-Large (2-column)

    private var extraLargeLayout: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left column
            VStack(alignment: .leading, spacing: 16) {
                header
                balanceCard
                incomeExpenseRow
                StandByUpcomingCard(
                    payments: snap.scheduledPayments,
                    currency: snap.currency
                )
                Spacer()
            }

            // Right column
            VStack(alignment: .leading, spacing: 16) {
                weeklySparkline
                if !snap.budgetStatuses.isEmpty { budgetRingRow }
                savingsCard
                Spacer()
            }
        }
        .padding(28)
    }

    // MARK: - Large (1-column)

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            balanceCard
            incomeExpenseRow
            weeklySparkline
            if !snap.budgetStatuses.isEmpty { budgetRingRow }
            StandByUpcomingCard(
                payments: snap.scheduledPayments,
                currency: snap.currency
            )
            Spacer()
        }
        .padding(22)
    }

    // MARK: - Background

    private var background: some View {
        let pColor = Color(hex: snap.accentPrimaryHex ?? "#5E5CE6")
        let sColor = Color(hex: snap.accentSecondaryHex ?? "#7D7AFF")
        
        return ZStack {
            LinearGradient(
                colors: [
                    pColor.opacity(0.12),
                    Color(hex: "#09091E")
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)

            // Ambient glow blobs
            Circle()
                .fill(pColor.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -100, y: -80)

            Circle()
                .fill(sColor.opacity(0.12))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: 120, y: 160)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LinearGradient(
                    colors: [accentPrimary, accentSecondary],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("ZFlow")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(sbText)

            Spacer()

            Text(snap.updatedAt, style: .relative)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(sbTextSec)
        }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NET BALANCE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(sbTextSec)
                .tracking(1.2)

            Text(net.formattedCurrencySimple(code: snap.currency))
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(netPositive ? sbText : sbRed)
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            // Savings rate pill
            HStack(spacing: 5) {
                Image(systemName: netPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(netPositive ? sbGreen : sbRed)
                Text(netPositive ? "Savings rate: \(savingsRate)%" : "Over budget this month")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(netPositive ? sbGreen : sbRed)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(netPositive ? sbCardFill : Color.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(netPositive ? sbBorder : sbRed.opacity(0.30), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Income / Expense Row

    private var incomeExpenseRow: some View {
        HStack(spacing: 10) {
            statPill(icon: "arrow.up.circle.fill", label: NSLocalizedString("dashboard.income", comment: ""), value: snap.thisMonthIncome, color: sbGreen)
            statPill(icon: "arrow.down.circle.fill", label: NSLocalizedString("dashboard.expense", comment: ""), value: snap.thisMonthExpense, color: sbRed)
        }
    }

    private func statPill(icon: String, label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(sbTextSec)
                Text(value.formattedCurrencySimple(code: snap.currency))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(sbText)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(sbCardFill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(sbBorder, lineWidth: 0.8))
        )
    }

    // MARK: - Weekly Sparkline

    private var weeklySparkline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEEKLY EXPENSES")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(sbTextSec)
                .tracking(1.0)

            let maxVal = snap.weeklyExpenses.max() ?? 1
            let labels = ["M", "T", "W", "T", "F", "S", "S"]

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<7, id: \.self) { i in
                    let h = maxVal > 0 ? CGFloat(snap.weeklyExpenses[i] / maxVal) : 0
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [sbRed.opacity(0.5), sbRed],
                                    startPoint: .bottom, endPoint: .top))
                            .frame(height: max(4, h * 40))
                        Text(labels[i])
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(sbTextSec)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 54)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(sbCardFill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(sbBorder, lineWidth: 0.8))
        )
    }

    // MARK: - Budget Ring Row

    private var budgetRingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BUDGETS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(sbTextSec)
                .tracking(1.0)

            HStack(spacing: 14) {
                ForEach(snap.budgetStatuses.prefix(4)) { b in
                    VStack(spacing: 5) {
                        BudgetRing(budget: b, size: 42, strokeWidth: 4)
                        Text(b.categoryName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(sbTextSec)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(sbCardFill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(sbBorder, lineWidth: 0.8))
        )
    }

    // MARK: - Savings Card

    private var savingsCard: some View {
        let saved = max(0, snap.thisMonthIncome - snap.thisMonthExpense)
        return VStack(alignment: .leading, spacing: 6) {
            Text("THIS MONTH SAVED")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(sbTextSec)
                .tracking(1.0)
            Text(saved.formattedCurrencySimple(code: snap.currency))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(sbGreen)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            // Donut bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    let ratio = snap.thisMonthIncome > 0
                        ? min(CGFloat(saved / snap.thisMonthIncome), 1.0)
                        : 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [accentPrimary, sbGreen], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * ratio, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(sbCardFill)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(sbBorder, lineWidth: 0.8))
        )
    }
}

