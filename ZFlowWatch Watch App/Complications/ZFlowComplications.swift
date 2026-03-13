import WidgetKit
import SwiftUI

// MARK: - Watch Timeline Entry

struct WatchEntry: TimelineEntry {
    var date: Date
    var snapshot: ZFlowSnapshot
}

// MARK: - Watch Provider

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: .now, snapshot: SnapshotStore.shared.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = WatchEntry(date: .now, snapshot: SnapshotStore.shared.load())
        let next  = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Complication Bundle
// ⚠️ @main YOK — ZFlowWatchApp.swift'te zaten var

struct ZFlowComplicationBundle: WidgetBundle {
    var body: some Widget {
        ZFlowBudgetComplication()
        ZFlowBalanceComplication()
        ZFlowTodayComplication()
    }
}

// MARK: - Budget Complication

struct ZFlowBudgetComplication: Widget {
    let kind = "ZFlowBudgetComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            BudgetComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ZFlow Budget")
        .description("Shows your top budget status.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

struct BudgetComplicationView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) var family
    private var top: SnapshotBudget? { entry.snapshot.budgetStatuses.first }

    var body: some View {
        switch family {
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        case .accessoryCorner:      cornerView
        default:                    inlineView
        }
    }

    private var circularView: some View {
        ZStack {
            if let b = top {
                let color = wColor(b.statusColor.hex)
                Gauge(value: min(b.ratio, 1.0), in: 0...1) {
                    Image(systemName: b.categoryIcon).font(.system(size: 10))
                } currentValueLabel: {
                    Text("\(b.percentage)%")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .gaugeStyle(.accessoryCircular)
                .tint(Gradient(colors: [color.opacity(0.5), color]))
                .widgetAccentable()
            } else {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .bold))
                    .widgetAccentable()
            }
        }
    }

    private var rectangularView: some View {
        Group {
            if let b = top {
                let color = wColor(b.statusColor.hex)
                Gauge(value: min(b.ratio, 1.0), in: 0...1) {
                    Label(b.categoryName, systemImage: b.categoryIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .widgetAccentable()
                } currentValueLabel: {
                    Text("\(b.percentage)% · \(b.spent.formattedShort())/\(b.limit.formattedShort())")
                        .font(.system(size: 10, weight: .medium))
                }
                .gaugeStyle(.accessoryLinear)
                .tint(Gradient(colors: [color.opacity(0.4), color]))
                .widgetAccentable()
            } else {
                Label("No budgets", systemImage: "chart.bar")
                    .font(.system(size: 12))
                    .widgetAccentable()
            }
        }
    }

    private var inlineView: some View {
        Group {
            if let b = top {
                Label("\(b.categoryName): \(b.percentage)%",
                      systemImage: b.isExceeded ? "exclamationmark.triangle.fill" : b.categoryIcon)
                .widgetAccentable()
            } else {
                Label(entry.snapshot.netBalance.formattedShort() + " " + entry.snapshot.currency,
                      systemImage: "chart.line.uptrend.xyaxis")
                .widgetAccentable()
            }
        }
    }

    private var cornerView: some View {
        Group {
            if let b = top {
                Image(systemName: b.categoryIcon)
                    .font(.system(size: 18))
                    .widgetAccentable()
                    .widgetLabel {
                        Text("\(b.percentage)%")
                            .foregroundColor(wColor(b.statusColor.hex))
                    }
            } else {
                Image(systemName: "chart.bar.fill")
                    .widgetAccentable()
            }
        }
    }
}


// MARK: - Balance Complication

struct ZFlowBalanceComplication: Widget {
    let kind = "ZFlowBalanceComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            BalanceComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ZFlow Balance")
        .description("Net balance on your watch face.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

struct BalanceComplicationView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) var family
    private var snap: ZFlowSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(
                value: min(max(snap.thisMonthExpense / max(snap.thisMonthIncome, 1), 0), 1),
                in: 0...1
            ) {
                Image(systemName: "chart.line.uptrend.xyaxis")
            } currentValueLabel: {
                Text(snap.netBalance.formattedShort())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [wColor("#5E5CE6").opacity(0.4), wColor("#7D7AFF")]))
            .widgetAccentable()

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .bold))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text(snap.netBalance.formattedCurrencySimple(code: snap.currency))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("↑ \(snap.thisMonthIncome.formattedShort())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                        Text("↓ \(snap.thisMonthExpense.formattedShort())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
            .widgetAccentable()

        case .accessoryCorner:
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 18))
                .widgetAccentable()
                .widgetLabel {
                    Text(snap.netBalance.formattedShort())
                        .foregroundColor(wAccent)
                }

        default:
            Label(snap.netBalance.formattedCurrencySimple(code: snap.currency),
                  systemImage: "chart.line.uptrend.xyaxis")
            .widgetAccentable()
        }
    }
}

// MARK: - Today's Spent Complication

struct ZFlowTodayComplication: Widget {
    let kind = "ZFlowTodayComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            TodayComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ZFlow Today")
        .description("Your total spending today.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

struct TodayComplicationView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) var family

    private var todaySpent: Double {
        // Simple logic: user the weeklyExpenses[last] as today's proxy if not strictly tracked 
        // or just show recent transactions from today
        let today = Calendar.current.startOfDay(for: Date())
        return entry.snapshot.recentTransactions
            .filter { $0.type == "expense" && $0.date >= today }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle().stroke(wExpense.opacity(0.15), lineWidth: 3)
                Text(todaySpent.formattedShort())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .widgetAccentable()
            
        case .accessoryCorner:
            Image(systemName: "cart.fill")
                .font(.system(size: 18))
                .foregroundColor(wExpense)
                .widgetLabel {
                    Text(todaySpent.formattedShort() + " " + entry.snapshot.currency)
                }

        default:
            Label(todaySpent.formattedShort() + " " + entry.snapshot.currency, systemImage: "cart.fill")
                .widgetAccentable()
        }
    }
}

// MARK: - Watch Placeholder (Widget target'ındaki ile çakışmaz)

extension ZFlowSnapshot {
    static var placeholder: ZFlowSnapshot {
        ZFlowSnapshot(
            netBalance: 12_840,
            thisMonthIncome: 18_500,
            thisMonthExpense: 5_660,
            currency: "TRY",
            recentTransactions: [],
            budgetStatuses: [
                SnapshotBudget(
                    id: UUID(), categoryName: "Food",
                    categoryIcon: "fork.knife", categoryColor: "#FB7185",
                    limit: 3000, spent: 2100, currency: "TRY"),
            ],
            weeklyExpenses: Array(repeating: 0, count: 7),
            updatedAt: Date(),
            userDisplayName: "ZFlow",
            userType: "personal")
    }
}
