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

                // ── Quick Links ──────────────────────────
                HStack(spacing: 6) {
                    NavigationLink(destination: WatchReportsView()) {
                        quickLinkContent(icon: "chart.pie.fill", label: Localizer.shared.l("watch.reports"), color: wAccent)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: WatchCurrencyView()) {
                        quickLinkContent(icon: "coloncurrencysign.arrow.trianglehead.counterclockwise.rotate.90", label: Localizer.shared.l("watch.convert"), color: wWarning)
                    }
                    .buttonStyle(.plain)
                }

                // ── Quick Add ─────────────────────────────
                Button {
                    showQuickAdd = true
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Label(Localizer.shared.l("action.addTransaction"), systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(wAccent)
            }
            .padding(.horizontal, 2)
        }
        .background(
            RadialGradient(
                colors: [wAccent.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 120)
            .ignoresSafeArea()
        )
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
                            .foregroundStyle(wWarning)
                    }
                }
            }
        }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        ZStack {
            // Subtle brand-color ambient glow — "mesh glow" Liquid Glass hissiyatı OLED'de
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(wAccent.opacity(0.10))
                .blur(radius: 10)
                .padding(-4)

            // Glass base — near-black, NOT pure black; preserves OLED depth without harshness
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.06))
                .overlay(
                    // Soft gradient border — replaces the harsh .white.opacity(0.15) stroke
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.06), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                // Inner highlight — simulates glass thickness
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.035), lineWidth: 1.5)
                        .blur(radius: 1)
                )

            VStack(spacing: 6) {
                Text(Localizer.shared.l("widgets.netBalance"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text(snap.netBalance.formattedCurrencySimple(code: snap.currency))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                // Monthly direction chip
                let diff = snap.thisMonthIncome - snap.thisMonthExpense
                let chipColor = diff >= 0 ? wIncome : wExpense
                HStack(spacing: 4) {
                    Image(systemName: diff >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                        .font(.system(size: 11))
                    Text(diff.formattedShort() + " " + snap.currency)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(chipColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(chipColor.opacity(0.12)))
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
                    .foregroundStyle(wWarning)
                VStack(alignment: .leading, spacing: 1) {
                    let count = store.budgetAlerts.count
                    let key = count > 1 ? "watch.budgetAlerts" : "watch.budgetAlert"
                    Text(String(format: Localizer.shared.l(key), count))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    Text(Localizer.shared.l("watch.tapViewDetails"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(wWarning.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Income / Expense Row

    private var incomeExpenseRow: some View {
        HStack(spacing: 8) {
            statTile(
                icon: "arrow.up.circle.fill",
                label: Localizer.shared.l("dashboard.income"),
                value: snap.thisMonthIncome,
                color: wIncome)
            statTile(
                icon: "arrow.down.circle.fill",
                label: Localizer.shared.l("dashboard.expense"),
                value: snap.thisMonthExpense,
                color: wExpense)
        }
    }

    private func statTile(icon: String, label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value.formattedShort())
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Localizer.shared.l("dashboard.budgets"))
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

    // MARK: - Quick Link

    private func quickLinkContent(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Last Transaction

    private func lastTransactionCard(_ txn: SnapshotTransaction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Localizer.shared.l("watch.lastTransaction"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(wColor(txn.categoryColor).opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: txn.categoryIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(wColor(txn.categoryColor))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(Localizer.shared.category(txn.categoryName))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(txn.date, style: .relative)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                Spacer()
                Text("\(txn.type == "income" ? "+" : "−")\(txn.amount.formattedShort())")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(txn.type == "income" ? wIncome : wExpense)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Budget Row (Watch)

struct WatchBudgetRow: View {
    let budget: SnapshotBudget
    private var color: Color { wColor(budget.statusColor.hex) }

    var body: some View {
        HStack(spacing: 12) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.20), lineWidth: 3.5)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: CGFloat(min(budget.ratio, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(Localizer.shared.category(budget.categoryName))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(budget.spent.formattedShort()) / \(budget.limit.formattedShort())")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(budget.percentage)%")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
