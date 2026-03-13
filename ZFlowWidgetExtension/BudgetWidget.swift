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
                .containerBackground(for: .widget) { WidgetGradientBackground(snapshot: entry.snapshot) }
        }
        .configurationDisplayName("ZFlow Budgets")
        .description("Track your spending limits at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Budget Widget View

struct BudgetWidgetView: View {
    let entry: ZFlowEntry
    @Environment(\.widgetFamily) var family

    private var budgets: [SnapshotBudget] {
        // Prefer categories with actual spending (active), fall back to all budgets
        let all = entry.snapshot.budgetStatuses
        let active = all.filter { $0.spent > 0 }
        let source = active.isEmpty ? all : active
        let limit: Int
        if family == .systemSmall { limit = 1 }
        else if family == .systemLarge { limit = 6 }
        else { limit = 3 }
        return Array(source.prefix(limit))
    }

    var body: some View {
        if budgets.isEmpty {
            emptyView
        } else if family == .systemSmall {
            smallView
        } else if family == .systemLarge {
            largeView
        } else {
            mediumView
        }
    }

    // MARK: Small — 1 budget as large ring (158×158pt)

    private var smallView: some View {
        guard let b = budgets.first else { return AnyView(emptyView) }
        return AnyView(
            ZStack {
                WidgetGlassBackground()
                VStack(spacing: 6) {
                    // Compact header
                    HStack(spacing: 3) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.primary)
                        Text("ZFlow")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 13)
                    .padding(.top, 11)

                    // Centered ring
                    VStack {
                        BudgetRing(budget: b, size: 88, strokeWidth: 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Category label & amounts
                    VStack(spacing: 2) {
                        Text(Localizer.shared.category(b.categoryName))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text("\(b.spent.formattedShort())/\(b.limit.formattedShort())")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 11)

                    Spacer()
                }
            }
        )
    }

    // MARK: Medium — 3 budgets as mini rings (338×158pt)

    private var mediumView: some View {
        ZStack {
            WidgetGlassBackground()
            VStack(alignment: .leading, spacing: 0) {
                // Compact header
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Text("ZFlow")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(Localizer.shared.l("widgets.budgets"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)

                Divider().opacity(0.25).padding(.horizontal, 18)

                // Budget rows — compact
                VStack(spacing: 0) {
                    ForEach(Array(budgets.enumerated()), id: \.element.id) { idx, b in
                        BudgetRowCompact(budget: b, currency: entry.snapshot.currency)
                        if idx < budgets.count - 1 {
                            Divider().opacity(0.12).padding(.leading, 60)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

                Spacer()
            }
        }
    }

    // MARK: Large — up to 6 budgets (338×354pt)

    private var largeView: some View {
        ZStack {
            WidgetGlassBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Text("ZFlow")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(Localizer.shared.l("widgets.budgets"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)

                Divider().opacity(0.25).padding(.horizontal, 18)

                VStack(spacing: 0) {
                    ForEach(Array(budgets.enumerated()), id: \.element.id) { idx, b in
                        BudgetRowCompact(budget: b, currency: entry.snapshot.currency)
                        if idx < budgets.count - 1 {
                            Divider().opacity(0.12).padding(.leading, 60)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

                Spacer()
            }
        }
    }

    private var emptyView: some View {
        ZStack {
            WidgetGlassBackground()
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.primary)
                Text(Localizer.shared.l("widgets.noBudgets"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }

}

// MARK: - Budget Ring

struct BudgetRing: View {
    let budget: SnapshotBudget
    let size: CGFloat
    let strokeWidth: CGFloat

    private var color: Color { 
        budget.isExceeded ? Color(hex: "#FF453A") : Color(hex: budget.statusColor.hex) 
    }
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
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(budget.isExceeded ? 0.3 : 0), radius: 4)

            // Center
            VStack(spacing: 0) {
                Image(systemName: budget.categoryIcon)
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundColor(color)
                
                HStack(spacing: 1) {
                    Text("\(budget.percentage)")
                        .font(.system(size: size * 0.18, weight: .thin, design: .rounded))
                    Text("%")
                        .font(.system(size: size * 0.12, weight: .thin, design: .rounded))
                        .baselineOffset(size * 0.02)
                }
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
        HStack(spacing: 8) {
            // Mini ring
            BudgetRing(budget: budget, size: 32, strokeWidth: 3.5)

            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 3) {
                    Text(Localizer.shared.category(budget.categoryName))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if budget.isExceeded {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "#FF453A"))
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color.opacity(0.12))
                            .frame(height: 2.5)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(min(budget.ratio, 1.0)), height: 2.5)
                    }
                }
                .frame(height: 2.5)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0.5) {
                Text(budget.spent.formattedShort())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                Text("/ \(budget.limit.formattedShort())")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 7)
    }
}
