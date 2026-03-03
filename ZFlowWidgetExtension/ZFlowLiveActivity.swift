// ============================================================
// ZFlow — Live Activity + Dynamic Island — Views
// Target: ZFlowWidgetExtension
// ZFlowActivityAttributes ve ZFlowLiveActivityManager:
//   → Ecosystem/Shared/ZFlowLiveActivityManager.swift (main app)
// iOS 16.1+  |  ActivityKit + WidgetKit
// ============================================================
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget


struct ZFlowLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ZFlowActivityAttributes.self) { context in
            // Lock Screen expanded banner
            LockScreenLiveActivity(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (kullanıcı basılı tuttuğunda)
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(context: context)
                }
            } compactLeading: {
                // Sol kompakt — ZFlow ikonunu
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            } compactTrailing: {
                // Sağ kompakt — bakiye veya bütçe uyarısı
                CompactTrailing(context: context)
            } minimal: {
                // Minimal — sadece ikon
                MinimalView(context: context)
            }
            .keylineTint(Color(hex: "#5E5CE6"))
            .contentMargins(.horizontal, 10, for: .expanded)
            .contentMargins(.top, 6, for: .expanded)
        }
    }
}

// MARK: - Lock Screen Banner

struct LockScreenLiveActivity: View {
    let context: ActivityViewContext<ZFlowActivityAttributes>

    var state: ZFlowActivityAttributes.ContentState { context.state }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#07071C"))

            HStack(spacing: 16) {
                // Left — ZFlow logo + balance
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("ZFlow")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text(state.netBalance.formattedCurrencySimple(code: context.attributes.currency))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                }

                Spacer()

                // Right — Income | Expense
                VStack(alignment: .trailing, spacing: 6) {
                    statRow(
                        icon: "arrow.down.circle.fill",
                        value: state.thisMonthIncome,
                        color: Color(hex: "#50C878"),
                        currency: context.attributes.currency)
                    statRow(
                        icon: "arrow.up.circle.fill",
                        value: state.thisMonthExpense,
                        color: Color(hex: "#FF7F7F"),
                        currency: context.attributes.currency)
                }

                // Budget alert badge (varsa)
                if let name = state.alertBudgetName,
                   let pct  = state.alertBudgetPercent,
                   let hexC = state.alertBudgetColor {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hexC).opacity(0.20))
                                .frame(width: 40, height: 40)
                            Text("\(pct)%")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: hexC))
                        }
                        Text(name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                            .frame(maxWidth: 44)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private func statRow(icon: String, value: Double, color: Color, currency: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value.formattedShort() + " " + currency)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.80))
        }
    }
}

// MARK: - Dynamic Island Expanded Regions

struct ExpandedLeading: View {
    let context: ActivityViewContext<ZFlowActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("ZFlow")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.80))
            }
            Text(context.state.netBalance.formattedCurrencySimple(code: context.attributes.currency))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

struct ExpandedTrailing: View {
    let context: ActivityViewContext<ZFlowActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Label(context.state.thisMonthIncome.formattedShort(),
                  systemImage: "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#50C878"))

            Label(context.state.thisMonthExpense.formattedShort(),
                  systemImage: "arrow.up.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#FF7F7F"))
        }
    }
}

struct ExpandedCenter: View {
    let context: ActivityViewContext<ZFlowActivityAttributes>

    var body: some View {
        if let cat = context.state.lastTransactionCategory,
           let icon = context.state.lastTransactionIcon,
           let amount = context.state.lastTransactionAmount,
           let type = context.state.lastTransactionType {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(type == "income" ? Color(hex: "#50C878") : Color(hex: "#FF7F7F"))
                VStack(alignment: .leading, spacing: 1) {
                    Text(cat)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.80))
                    Text("\(type == "income" ? "+" : "−")\(amount.formattedShort()) \(context.attributes.currency)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(type == "income" ? Color(hex: "#50C878") : Color(hex: "#FF7F7F"))
                }
            }
        }
    }
}

struct ExpandedBottom: View {
    let context: ActivityViewContext<ZFlowActivityAttributes>

    var body: some View {
        if let name = context.state.alertBudgetName,
           let pct  = context.state.alertBudgetPercent,
           let hexC = context.state.alertBudgetColor {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: hexC))
                Text("\(name): \(pct)% of budget used")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                // Mini ring
                ZStack {
                    Circle()
                        .stroke(Color(hex: hexC).opacity(0.25), lineWidth: 2.5)
                        .frame(width: 20, height: 20)
                    Circle()
                        .trim(from: 0, to: CGFloat(pct) / 100)
                        .stroke(Color(hex: hexC), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(-90))
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Compact Trailing

struct CompactTrailing: View {
    let context: ActivityViewContext<ZFlowActivityAttributes>

    var body: some View {
        if let pct = context.state.alertBudgetPercent,
           let hexC = context.state.alertBudgetColor {
            // Budget alert takes priority
            Text("\(pct)%")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: hexC))
        } else {
            // Net balance
            Text(context.state.netBalance.formattedShort())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Minimal

struct MinimalView: View {
    let context: ActivityViewContext<ZFlowActivityAttributes>

    var body: some View {
        if let hexC = context.state.alertBudgetColor {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: hexC))
        } else {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

