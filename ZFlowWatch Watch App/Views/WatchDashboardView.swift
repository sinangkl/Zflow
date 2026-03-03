// ============================================================
// ZFlow Watch — Dashboard (Ana Ekran)
// ============================================================
import SwiftUI
import WatchKit

struct WatchDashboardView: View {
    @EnvironmentObject var store: WatchStore
    @State private var showQuickAdd = false
    @State private var showAlerts   = false

    var snap: ZFlowSnapshot { store.snapshot }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                // ── Net Balance Hero ──────────────────────
                balanceCard

                // ── Budget Alert Badge (öncelikli!) ───────
                if !store.budgetAlerts.isEmpty {
                    alertBadge
                }

                // ── Income / Expense Row ──────────────────
                incomeExpenseRow

                // ── Budget Rings ──────────────────────────
                if !snap.budgetStatuses.isEmpty {
                    budgetSection
                }

                // ── Recent Transaction ────────────────────
                if let last = snap.recentTransactions.first {
                    lastTransactionCard(last)
                }

                // ── Quick Add ─────────────────────────────
                Button {
                    showQuickAdd = true
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Label("Add Transaction", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(wColor("#5E5CE6"))
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle("ZFlow")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showQuickAdd) {
            WatchQuickAddView()
        }
        .sheet(isPresented: $showAlerts) {
            WatchBudgetAlertsView()
        }
        // Budget alert modal — öncelikli özellik
        .sheet(item: $store.showBudgetAlert) { alert in
            WatchBudgetAlertModal(payload: alert)
        }
        .toolbar {
            if !store.budgetAlerts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAlerts = true
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(wColor("#FF9F0A"))
                    }
                }
            }
        }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [wColor("#0D0D1E"), wColor("#1A1A3A")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(spacing: 4) {
                Text("Net Balance")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.4)

                Text(snap.netBalance.formattedCurrencySimple(code: snap.currency))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                // Monthly direction
                let diff = snap.thisMonthIncome - snap.thisMonthExpense
                HStack(spacing: 3) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.left")
                        .font(.system(size: 9, weight: .bold))
                    Text(diff.formattedShort() + " " + snap.currency)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(diff >= 0 ? wColor("#50C878") : wColor("#FF7F7F"))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
        }
    }

    // MARK: - Alert Badge

    private var alertBadge: some View {
        Button {
            showAlerts = true
            WKInterfaceDevice.current().play(.click)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(wColor("#FF9F0A"))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(store.budgetAlerts.count) Budget Alert\(store.budgetAlerts.count > 1 ? "s" : "")")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Tap to view details")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(wColor("#FF9F0A").opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(wColor("#FF9F0A").opacity(0.35), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Income / Expense Row

    private var incomeExpenseRow: some View {
        HStack(spacing: 8) {
            statTile(
                icon: "arrow.down.circle.fill",
                label: "Income",
                value: snap.thisMonthIncome,
                color: wColor("#50C878"))
            statTile(
                icon: "arrow.up.circle.fill",
                label: "Expense",
                value: snap.thisMonthExpense,
                color: wColor("#FF7F7F"))
        }
    }

    private func statTile(icon: String, label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value.formattedShort())
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.10)))
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Budgets")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)

            ForEach(snap.budgetStatuses.prefix(3)) { b in
                NavigationLink(destination: WatchBudgetDetailView(budget: b)) {
                    WatchBudgetRow(budget: b)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Last Transaction

    private func lastTransactionCard(_ txn: SnapshotTransaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last Transaction")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(wColor(txn.categoryColor).opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: txn.categoryIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(wColor(txn.categoryColor))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(txn.categoryName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(txn.date, style: .relative)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(txn.type == "income" ? "+" : "−")\(txn.amount.formattedShort())")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(txn.type == "income" ? wColor("#50C878") : wColor("#FF7F7F"))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.15)))
    }
}

// MARK: - Budget Row (Watch)

struct WatchBudgetRow: View {
    let budget: SnapshotBudget
    private var color: Color { wColor(budget.statusColor.hex) }

    var body: some View {
        HStack(spacing: 8) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.20), lineWidth: 3)
                    .frame(width: 26, height: 26)
                Circle()
                    .trim(from: 0, to: CGFloat(min(budget.ratio, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(-90))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(budget.categoryName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(budget.spent.formattedShort()) / \(budget.limit.formattedShort())")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(budget.percentage)%")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.06)))
    }
}
