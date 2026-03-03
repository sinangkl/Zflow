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
                .containerBackground(.fill.tertiary, for: .widget)
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
                        .stroke(.secondary.opacity(0.25), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Image(systemName: topBudget.categoryIcon)
                            .font(.system(size: 11, weight: .bold))
                        Text("\(topBudget.percentage)%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                }
            } else {
                // No budgets — show net balance
                VStack(spacing: 0) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .bold))
                    Text(entry.snapshot.netBalance.formattedShort())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
            }
        }
        .widgetAccentable()
    }

    // Rectangular — balance + income/expense
    private var rectangularView: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .bold))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(
                        entry.snapshot.thisMonthIncome.formattedShort(),
                        systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)

                    Label(
                        entry.snapshot.thisMonthExpense.formattedShort(),
                        systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
                }
            }
        }
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
                .containerBackground(.fill.tertiary, for: .widget)
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
            Color(.systemBackground)
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accentGrad)
                        Text("ZFlow")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(accentGrad)
                    }
                    Spacer()
                    Text("Recent Transactions")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if family == .systemLarge {
                    // Balance summary bar
                    HStack(spacing: 16) {
                        balancePill(
                            label: "Income",
                            value: entry.snapshot.thisMonthIncome,
                            color: Color(hex: "#50C878"))
                        balancePill(
                            label: "Expense",
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
                            Text("No transactions yet")
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

    private var accentGrad: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - StandBy Widget (iOS 17+ fullscreen always-on)

struct ZFlowStandbyWidget: Widget {
    let kind = "ZFlowStandbyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            StandbyWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("ZFlow StandBy")
        .description("Full-screen financial overview in StandBy mode.")
        .supportedFamilies([.systemExtraLarge])
    }
}

struct StandbyWidgetView: View {
    let entry: ZFlowEntry

    var body: some View {
        ZStack {
            // Deep gradient background
            LinearGradient(
                colors: [Color(hex: "#000008"), Color(hex: "#07071C")],
                startPoint: .top, endPoint: .bottom)

            VStack(spacing: 24) {
                // Logo + time
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("ZFlow")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Text(entry.snapshot.updatedAt, style: .relative)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                }

                // Net balance — huge
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Balance")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.50))
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Text(entry.snapshot.netBalance.formattedCurrencySimple(code: entry.snapshot.currency))
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }

                // Income / Expense row
                HStack(spacing: 20) {
                    standbyStatPill(
                        icon: "arrow.down.circle.fill",
                        label: "Income",
                        value: entry.snapshot.thisMonthIncome,
                        color: Color(hex: "#50C878"))
                    Rectangle().fill(.white.opacity(0.12)).frame(width: 0.5, height: 40)
                    standbyStatPill(
                        icon: "arrow.up.circle.fill",
                        label: "Expense",
                        value: entry.snapshot.thisMonthExpense,
                        color: Color(hex: "#FF7F7F"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.07)))

                // Top budget ring row
                if !entry.snapshot.budgetStatuses.isEmpty {
                    HStack(spacing: 14) {
                        ForEach(entry.snapshot.budgetStatuses.prefix(3)) { b in
                            VStack(spacing: 6) {
                                BudgetRing(budget: b, size: 48, strokeWidth: 5)
                                Text(b.categoryName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(28)
        }
    }

    private func standbyStatPill(icon: String, label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                Text(value.formattedCurrencySimple(code: entry.snapshot.currency))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
