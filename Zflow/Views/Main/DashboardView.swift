import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @Environment(\.colorScheme) var scheme

    var onAddTapped: () -> Void = {}
    var onScrollChanged: ((Bool) -> Void)? = nil   // true = aşağı, false = yukarı
    @State private var showInsights = false
    @State private var showEditProfile = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var transactionToDelete: Transaction? = nil
    @State private var transactionToEdit: Transaction? = nil

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
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .named("dashScroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "dashScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    let delta = offset - lastScrollOffset
                    // Sadece belirgin bir scroll olduğunda tab bar'ı gizle/göster
                    if abs(delta) > 8 {
                        onScrollChanged?(delta < 0)  // negatif = aşağı scroll
                    }
                    lastScrollOffset = offset
                }
            }
            .navigationTitle(greetingTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView().environmentObject(authVM)
            }
            .sheet(item: $transactionToEdit) { txn in
                EditTransactionView(transaction: txn)
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
            .confirmationDialog(
                NSLocalizedString("common.delete", comment: "Delete"),
                isPresented: Binding(
                    get: { transactionToDelete != nil },
                    set: { if !$0 { transactionToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("common.delete", comment: "Delete"), role: .destructive) {
                    if let txn = transactionToDelete, let uid = authVM.currentUserId {
                        Task {
                            await transactionVM.deleteTransaction(id: txn.id, userId: uid)
                            Haptic.success()
                        }
                        transactionToDelete = nil
                    }
                }
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                    transactionToDelete = nil
                }
            } message: {
                Text(NSLocalizedString("common.deleteWarning", comment: "This action cannot be undone."))
            }
        }
    }


    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showEditProfile = true
                Haptic.light()
            } label: {
                if let data = authVM.userAvatarData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                } else {
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
            .accessibilityLabel("Edit profile")
        }
    }

    // MARK: - Hero Card
    // HIG: Net balance en üst hiyerarşide, büyük ve bold

    private var heroCard: some View {
        GradientCard(gradient: AppTheme.accentGradient) {
            VStack(spacing: 16) {
                // Balance label
                VStack(spacing: 4) {
                    Text(NSLocalizedString("dashboard.netBalance", comment: ""))
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
                        label: NSLocalizedString("dashboard.income", comment: ""),
                        amount: transactionVM.thisMonthIncome,
                        icon: "arrow.down.circle.fill",
                        tint: Color(hex: "#86EFAC")) // soft green, kontrast on purple bg

                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 0.5, height: 44)

                    incomeExpenseChip(
                        label: NSLocalizedString("dashboard.expense", comment: ""),
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
                title: NSLocalizedString("dashboard.monthlyChange", comment: ""),
                value: expenseChangeText,
                icon: "arrow.up.arrow.down.circle.fill",
                iconColor: expenseChangeColor,
                valueColor: expenseChangeColor,
                trend: transactionVM.expenseChangePercent)

            StatCard(
                title: NSLocalizedString("dashboard.transactions", comment: ""),
                value: "\(transactionVM.transactions.count)",
                icon: "list.number",
                iconColor: ZColor.purple)
        }
    }

    private var expenseChangeText: String {
        guard let pct = transactionVM.expenseChangePercent else { return "No prev. month" }
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
                title: NSLocalizedString("dashboard.insights", comment: ""),
                trailing: showInsights ? NSLocalizedString("dashboard.showLess", comment: "") : NSLocalizedString("dashboard.showMore", comment: "")) {
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
                SectionHeader(title: NSLocalizedString("dashboard.budgets", comment: ""))

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
            SectionHeader(title: NSLocalizedString("dashboard.recent", comment: ""))

            if transactionVM.isLoading {
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        ShimmerView(height: 62, cornerRadius: 12)
                    }
                }
            } else if transactionVM.transactions.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: NSLocalizedString("dashboard.noTransactions", comment: ""),
                    message: NSLocalizedString("dashboard.addFirst", comment: ""),
                    actionLabel: NSLocalizedString("dashboard.addTransaction", comment: ""),
                    action: onAddTapped)
                .zFlowCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(transactionVM.transactions.prefix(5).enumerated()), id: \.element.id) { idx, txn in
                        TransactionRow(
                            transaction: txn,
                            category: transactionVM.category(for: txn.categoryId))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                transactionToDelete = txn
                                Haptic.medium()
                            } label: {
                                Label(NSLocalizedString("common.delete", comment: "Delete"),
                                      systemImage: "trash.fill")
                            }
                            
                            Button {
                                transactionToEdit = txn
                                Haptic.light()
                            } label: {
                                Label(NSLocalizedString("common.edit", comment: "Edit"),
                                      systemImage: "pencil")
                            }
                            .tint(ZColor.indigo)
                        }
                        .contextMenu {
                            Button {
                                transactionToEdit = txn
                                Haptic.light()
                            } label: {
                                Label(NSLocalizedString("common.edit", comment: "Edit"), systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                transactionToDelete = txn
                                Haptic.medium()
                            } label: {
                                Label(NSLocalizedString("common.delete", comment: "Delete"), systemImage: "trash.fill")
                            }
                        }

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
        let name = authVM.userProfile?.displayName.components(separatedBy: " ").first ?? ""
        let greeting: String
        switch hour {
        case 0..<12:  greeting = NSLocalizedString("time.goodMorning", comment: "")
        case 12..<17: greeting = NSLocalizedString("time.goodAfternoon", comment: "")
        default:      greeting = NSLocalizedString("time.goodEvening", comment: "")
        }
        return name.isEmpty ? greeting : "\(greeting), \(name)"
    }
}

// MARK: - Scroll Offset Tracking

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
