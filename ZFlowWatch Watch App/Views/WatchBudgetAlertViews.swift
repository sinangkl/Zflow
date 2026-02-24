import SwiftUI
import WatchKit

// MARK: - Budget Alert Modal

struct WatchBudgetAlertModal: View {
    let payload: BudgetAlertPayload
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) var dismiss

    private var alertColor: Color {
        switch payload.alertType {
        case .exceeded: return wColor("#FF453A")
        case .critical: return wColor("#FF6961")
        case .warning:  return wColor("#FF9F0A")
        }
    }

    private var alertIcon: String {
        switch payload.alertType {
        case .exceeded: return "exclamationmark.octagon.fill"
        case .critical: return "exclamationmark.triangle.fill"
        case .warning:  return "bell.badge.fill"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(alertColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: alertIcon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(alertColor)
                }
                .padding(.top, 8)

                Text(payload.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(payload.body)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                ZStack {
                    Circle()
                        .stroke(alertColor.opacity(0.15), lineWidth: 6)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(payload.spent / payload.limit, 1.0)))
                        .stroke(alertColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(Int((payload.spent / payload.limit) * 100))%")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(alertColor)
                        Text(payload.categoryName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 0) {
                    budgetFigure(label: "Spent", value: payload.spent, color: alertColor)
                    Divider().frame(height: 32)
                    budgetFigure(label: "Limit", value: payload.limit, color: .secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.15)))

                Button {
                    WKInterfaceDevice.current().play(.success)
                    store.dismissAlert()
                    dismiss()
                } label: {
                    Text("Got It")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(alertColor)

                Button {
                    store.dismissAlert()
                    dismiss()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
    }

    private func budgetFigure(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            Text(value.formattedShort() + " " + payload.currency)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Budget Alerts List

struct WatchBudgetAlertsView: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.budgetAlerts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(wColor("#30D158"))
                        Text("All budgets on track!")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.budgetAlerts, id: \.categoryId) { alert in
                        BudgetAlertRow(payload: alert)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(wColor("#5E5CE6"))
                }
            }
        }
    }
}

struct BudgetAlertRow: View {
    let payload: BudgetAlertPayload

    private var alertColor: Color {
        switch payload.alertType {
        case .exceeded: return wColor("#FF453A")
        case .critical: return wColor("#FF6961")
        case .warning:  return wColor("#FF9F0A")
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(alertColor.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: payload.categoryIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(alertColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(payload.categoryName)
                    .font(.system(size: 13, weight: .bold))
                Text("\(Int((payload.spent / payload.limit) * 100))% used")
                    .font(.system(size: 11))
                    .foregroundColor(alertColor)
            }
            Spacer()
            Image(systemName:
                payload.alertType == .exceeded ? "exclamationmark.octagon.fill" :
                payload.alertType == .critical ? "exclamationmark.triangle.fill" :
                "bell.badge.fill")
                .font(.system(size: 14))
                .foregroundColor(alertColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Budget Detail View

struct WatchBudgetDetailView: View {
    let budget: SnapshotBudget
    private var color: Color { wColor(budget.statusColor.hex) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 8)
                        .frame(width: 90, height: 90)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(budget.ratio, 1.0)))
                        .stroke(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Image(systemName: budget.categoryIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(color)
                        Text("\(budget.percentage)%")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    }
                }
                .padding(.top, 8)

                Text(budget.categoryName)
                    .font(.system(size: 15, weight: .bold))

                HStack(spacing: 0) {
                    budgetStat("Spent", budget.spent.formattedShort(), color)
                    Divider().frame(height: 36)
                    budgetStat("Left",
                        max(0, budget.limit - budget.spent).formattedShort(),
                        budget.isExceeded ? wColor("#FF453A") : wColor("#30D158"))
                    Divider().frame(height: 36)
                    budgetStat("Limit", budget.limit.formattedShort(), .secondary)
                }
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.15)))

                if budget.isExceeded {
                    Label("Budget Exceeded!", systemImage: "exclamationmark.octagon.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(wColor("#FF453A"))
                } else if budget.isCritical {
                    Label("Almost at limit", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(wColor("#FF6961"))
                } else if budget.isWarning {
                    Label("80% used", systemImage: "bell.badge.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(wColor("#FF9F0A"))
                } else {
                    Label("On track", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(wColor("#30D158"))
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(budget.categoryName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func budgetStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
