import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @Environment(\.colorScheme) var scheme

    var onAddTapped: () -> Void = {}
    @State private var showInsights = false

    private var insights: [FinancialInsight] {
        InsightsEngine.generate(
            transactions: transactionVM.transactions,
            primaryCurrency: transactionVM.primaryCurrency,
            budgets: budgetManager.budgets)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroCard
                        statsRow
                        if !insights.isEmpty { insightsSection }
                        budgetSection
                        recentSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 140) // FAB + tab bar clearance
                }
            }
            .navigationTitle(greetingTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 10) {
                // Refresh
                Button {
                    if let p = authVM.userProfile {
                        Task {
                            await transactionVM.refreshData(
                                userId: p.id, userType: p.userType ?? "personal")
                        }
                    }
                    Haptic.light()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ZColor.indigo)
                        // HIG minimum 44pt
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(ZColor.indigo.opacity(0.10))
                        )
                }

                // Avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.accentGradient)
                        .frame(width: 34, height: 34)
                    Text(authVM.userProfile?.initials ?? "Z")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Hero Card
    // HIG: Net balance en üst hiyerarşide, büyük ve bold

    private var heroCard: some View {
        GradientCard(gradient: AppTheme.accentGradient) {
            VStack(spacing: 16) {
                // Balance label
                VStack(spacing: 4) {
                    Text("Net Balance")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(transactionVM.netBalance.formattedCurrency(code: transactionVM.primaryCurrency))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: transactionVM.netBalance)
                }

                // Income / Expense
                HStack(spacing: 12) {
                    incomeExpenseChip(
                        label: "Income",
                        amount: transactionVM.thisMonthIncome,
                        icon: "arrow.down.circle.fill",
                        tint: Color(hex: "#86EFAC")) // soft green, kontrast on purple bg

                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 0.5, height: 44)

                    incomeExpenseChip(
                        label: "Expense",
                        amount: transactionVM.thisMonthExpense,
                        icon: "arrow.up.circle.fill",
                        tint: Color(hex: "#FCA5A5")) // soft red
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }

    private func incomeExpenseChip(label: String, amount: Double, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.70))
                    .textCase(.uppercase)
                    .tracking(0.3)
                Text(amount.formattedCurrency(code: transactionVM.primaryCurrency))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Monthly Change",
                value: expenseChangeText,
                icon: "arrow.up.arrow.down.circle.fill",
                iconColor: expenseChangeColor,
                valueColor: expenseChangeColor,
                trend: transactionVM.expenseChangePercent)

            StatCard(
                title: "Transactions",
                value: "\(transactionVM.transactions.count)",
                icon: "list.number",
                iconColor: ZColor.purple)
        }
    }

    private var expenseChangeText: String {
        guard let pct = transactionVM.expenseChangePercent else { return "No data" }
        return "\(pct >= 0 ? "+" : "")\(String(format: "%.1f", pct))%"
    }

    private var expenseChangeColor: Color {
        guard let pct = transactionVM.expenseChangePercent else { return ZColor.labelSec }
        return pct >= 0 ? ZColor.expense : ZColor.income
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(spacing: 10) {
            SectionHeader(
                title: "Insights",
                trailing: showInsights ? "Show Less" : "Show More") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showInsights.toggle()
                    }
                    Haptic.selection()
                }

            let displayed = showInsights ? insights : Array(insights.prefix(2))
            ForEach(displayed) { insight in
                InsightCard(insight: insight) { onAddTapped() }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity))
            }
        }
    }

    // MARK: - Budget Tracker

    private var budgetSection: some View {
        let catsWithBudget = transactionVM.categories.filter {
            budgetManager.budgets[$0.id] != nil
        }

        if catsWithBudget.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 10) {
                SectionHeader(title: "Budgets")

                VStack(spacing: 0) {
                    ForEach(Array(catsWithBudget.prefix(4).enumerated()), id: \.element.id) { idx, cat in
                        let limit  = budgetManager.budgets[cat.id] ?? 0
                        let spent  = transactionVM.categorySpending(categoryId: cat.id)
                        let ratio  = limit > 0 ? spent / limit : 0

                        budgetRow(cat: cat, spent: spent, limit: limit, ratio: ratio)

                        if idx < min(3, catsWithBudget.count - 1) {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .zFlowCard()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        )
    }

    private func budgetRow(cat: Category, spent: Double, limit: Double, ratio: Double) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: cat.color).opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: cat.icon ?? "circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: cat.color))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(cat.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ZColor.label)
                    Text("\(spent.formattedShort(code: transactionVM.primaryCurrency)) / \(limit.formattedShort(code: transactionVM.primaryCurrency))")
                        .font(.system(size: 12))
                        .foregroundColor(ZColor.labelSec)
                }

                Spacer()

                Text("\(Int(min(ratio * 100, 100)))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(budgetStatusColor(ratio: ratio))
            }

            BudgetProgressBar(spent: spent, limit: limit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func budgetStatusColor(ratio: Double) -> Color {
        if ratio >= 1.0 { return ZColor.expense }
        if ratio >= 0.8 { return ZColor.warning }
        return ZColor.income
    }

    // MARK: - Recent Transactions

    private var recentSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Recent")

            if transactionVM.isLoading {
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        ShimmerView(height: 62, cornerRadius: 12)
                    }
                }
            } else if transactionVM.transactions.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No Transactions Yet",
                    message: "Tap the + button to record your first transaction.",
                    actionLabel: "Add Transaction",
                    action: onAddTapped)
                .zFlowCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(transactionVM.transactions.prefix(5).enumerated()), id: \.element.id) { idx, txn in
                        TransactionRow(
                            transaction: txn,
                            category: transactionVM.category(for: txn.categoryId))

                        if idx < min(4, transactionVM.transactions.count - 1) {
                            Divider().padding(.leading, 70)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Helpers

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = authVM.userProfile?.displayName?.components(separatedBy: " ").first ?? ""
        let greeting: String
        switch hour {
        case 0..<12:  greeting = NSLocalizedString("time.goodMorning", comment: "")
        case 12..<17: greeting = NSLocalizedString("time.goodAfternoon", comment: "")
        default:      greeting = NSLocalizedString("time.goodEvening", comment: "")
        }
        return name.isEmpty ? greeting : "\(greeting), \(name)"
    }
}
