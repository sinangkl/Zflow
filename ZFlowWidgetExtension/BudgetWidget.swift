// ============================================================
// ZFlow — Budget Widget
// Bütçe durumunu ring'lerle gösterir
// Sizes: small, medium
// ============================================================
import WidgetKit
import SwiftUI

struct ZFlowBudgetWidget: Widget {
    let kind = "ZFlowBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            BudgetWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ZFlow Budgets")
        .description("Track your spending limits at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Budget Widget View

struct BudgetWidgetView: View {
    let entry: ZFlowEntry
    @Environment(\.widgetFamily) var family

    private var budgets: [SnapshotBudget] {
        entry.snapshot.budgetStatuses.prefix(family == .systemSmall ? 1 : 3).map { $0 }
    }

    var body: some View {
        if budgets.isEmpty {
            emptyView
        } else if family == .systemSmall {
            smallView
        } else {
            mediumView
        }
    }

    // MARK: Small — 1 budget as large ring

    private var smallView: some View {
        guard let b = budgets.first else { return AnyView(emptyView) }
        return AnyView(
            ZStack {
                Color(.systemBackground)
                VStack(spacing: 8) {
                    // Logo
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accentGrad)
                        Text("ZFlow")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(accentGrad)
                        Spacer()
                        if b.isExceeded {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#FF453A"))
                        }
                    }

                    Spacer()

                    // Ring
                    BudgetRing(budget: b, size: 80, strokeWidth: 10)

                    Text(b.categoryName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("\(b.spent.formattedShort()) / \(b.limit.formattedShort()) \(b.currency)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(12)
            }
        )
    }

    // MARK: Medium — 3 budgets as mini rings

    private var mediumView: some View {
        ZStack {
            Color(.systemBackground)
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentGrad)
                    Text("ZFlow")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(accentGrad)
                    Spacer()
                    Text("Budgets")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().padding(.horizontal, 14)

                // Budget rows
                VStack(spacing: 0) {
                    ForEach(Array(budgets.enumerated()), id: \.element.id) { idx, b in
                        BudgetRowCompact(budget: b, currency: entry.snapshot.currency)
                        if idx < budgets.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Spacer()
            }
        }
    }

    private var emptyView: some View {
        ZStack {
            Color(.systemBackground)
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("No Budgets Set")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var accentGrad: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Budget Ring

struct BudgetRing: View {
    let budget: SnapshotBudget
    let size: CGFloat
    let strokeWidth: CGFloat

    private var color: Color { Color(hex: budget.statusColor.hex) }
    private var ratio: CGFloat { CGFloat(min(budget.ratio, 1.0)) }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: strokeWidth)
                .frame(width: size, height: size)

            // Progress
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.65)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Center
            VStack(spacing: 1) {
                Image(systemName: budget.categoryIcon)
                    .font(.system(size: size * 0.18, weight: .medium))
                    .foregroundColor(color)
                Text("\(budget.percentage)%")
                    .font(.system(size: size * 0.18, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Budget Row Compact (Medium widget)

struct BudgetRowCompact: View {
    let budget: SnapshotBudget
    let currency: String
    private var color: Color { Color(hex: budget.statusColor.hex) }

    var body: some View {
        HStack(spacing: 10) {
            // Mini ring
            BudgetRing(budget: budget, size: 34, strokeWidth: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(budget.categoryName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if budget.isExceeded {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#FF453A"))
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.12))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(min(budget.ratio, 1.0)), height: 3)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(budget.spent.formattedShort())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
                Text("/ \(budget.limit.formattedShort())")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 9)
    }
}
