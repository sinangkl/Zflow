import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var scheduledPaymentVM: ScheduledPaymentViewModel
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @EnvironmentObject var goalVM: GoalViewModel
    @SceneStorage("selectedTab") private var selectedTab = 0

    var onAddTapped: () -> Void = {}
    var onChatTapped: () -> Void = {}
    var onScrollChanged: ((Bool) -> Void)? = nil
    var onSeeAllTransactions: () -> Void = {}  // → switches to Reports tab

    @State private var showInsights = false
    @State private var showEditProfile = false
    @State private var showGoalsSheet = false
    @State private var transactionToDelete: Transaction? = nil
    @State private var transactionToEdit: Transaction? = nil
    @State private var selectedTransaction: Transaction? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var showAllBudgets = false
    @AppStorage("profileCardColor") private var appThemeColorHex: String = "#5E5CE6"

    private var insights: [FinancialInsight] {
        InsightsEngine.generate(
            transactions: transactionVM.transactions,
            categories: transactionVM.categories,
            primaryCurrency: transactionVM.primaryCurrency,
            budgets: budgetManager.budgets,
            scheduledPayments: scheduledPaymentVM.scheduledPayments
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            MeshGradientBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    GeometryReader { proxy -> Color in
                        let minY = proxy.frame(in: .named("DashboardScroll")).minY
                        DispatchQueue.main.async {
                            scrollOffset = minY
                        }
                        return Color.clear
                    }
                    .frame(height: 0)

                    greetingHeader
                    heroCard
                    heroPills
                    quickActionsSection
                    statsRow
                    if !insights.isEmpty { aiInsightsSection }
                    budgetSection
                    goalsPreviewSection
                    cashFlowPreviewSection
                    scheduledPaymentsSection
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                if let p = authVM.userProfile {
                    Haptic.light()
                    await transactionVM.refreshData(userId: p.id, userType: p.userType ?? "personal")
                    await goalVM.fetchGoals(userId: p.id, familyId: p.familyId)
                }
            }
            .task {
                if let p = authVM.userProfile, goalVM.goals.isEmpty {
                    await goalVM.fetchGoals(userId: p.id, familyId: p.familyId)
                }
            }
            .coordinateSpace(name: "DashboardScroll")
            .clipped()

            // Apple-style frosted top bar — appears on scroll
            if scrollOffset < -20 {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .background(.ultraThinMaterial)
                }
                .frame(maxWidth: .infinity)
                .frame(height: max(0, 50))
                .background(.ultraThinMaterial)
                .opacity(min(1, Double(-scrollOffset - 20) / 40))
                .ignoresSafeArea(edges: .top)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.15), value: scrollOffset < -20)
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView().environmentObject(authVM)
        }
        .sheet(item: $transactionToEdit) { txn in
            EditTransactionView(transaction: txn)
                .environmentObject(transactionVM)
                .environmentObject(authVM)
        }
        .sheet(item: $selectedTransaction) { txn in
            TransactionDetailView(
                transaction: txn,
                category: transactionVM.category(for: txn.categoryId)
            )
            .environmentObject(transactionVM)
            .environmentObject(authVM)
        }
        .alert(
            NSLocalizedString("common.delete", comment: "Delete"),
            isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            )
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
            if let t = transactionToDelete {
                Text("\(t.amount.formattedCurrency(code: t.currency)) - \(NSLocalizedString("common.deleteConfirmation", comment: "Are you sure?"))")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showInsights = true
                Haptic.light()
            } label: {
                ZStack {
                    Circle()
                        .fill(ZColor.fillSec)
                        .frame(width: 44, height: 44) // HIG min 44×44pt
                    Image(systemName: "sparkles")
                        .eliteFont(size: 16, weight: .semibold, textStyle: .body)
                        .symbolEffect(.bounce, value: showInsights)
                        .foregroundStyle(AppTheme.accentGradient)
                }
            }
            .accessibilityLabel("AI Insights")
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let scale       = scrollOffset < 0 ? max(0.92, 1 + (scrollOffset / 800)) : 1.0
        let cardOpacity = scrollOffset < 0 ? max(0.70, 1 + (scrollOffset / 400)) : 1.0
        let accent      = Color(hex: appThemeColorHex)

        return ZStack {
            // Ambient glow — Apple 2026 signature depth effect
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.28), accent.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 280, height: 90)
                .blur(radius: 32)
                .offset(y: 24)

            VStack(spacing: 6) {
                // Kart üst etiketi
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ThemeColors.textSecondary)
                    Text(NSLocalizedString("dashboard.netBalance", comment: ""))
                        .eliteFont(size: 11, weight: .semibold, textStyle: .caption)
                        .foregroundStyle(ThemeColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1.0)
                }

                // Bakiye — büyük, bold
                Text(transactionVM.netBalance.formattedCurrency(code: transactionVM.primaryCurrency))
                    .eliteDashboardBalance()
                    .foregroundStyle(ThemeColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: transactionVM.netBalance)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                // Ay/yıl göstergesi
                Text(Date(), format: .dateTime.month(.wide).year())
                    .eliteFont(size: 12, weight: .regular, textStyle: .caption)
                    .foregroundStyle(ThemeColors.textSecondary.opacity(0.65))
                    .padding(.top, 2)
            }
            .padding(.vertical, 34)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
            .liquidGlass(cornerRadius: 28)
        }
        .scaleEffect(scale)
        .opacity(cardOpacity)
    }

    private var heroPills: some View {
        HStack(spacing: 12) {
            incomeExpenseChip(
                label: NSLocalizedString("dashboard.income", comment: ""),
                amount: transactionVM.thisMonthIncome,
                icon: "arrow.up.circle.fill",
                tint: ZColor.income
            )

            incomeExpenseChip(
                label: NSLocalizedString("dashboard.expense", comment: ""),
                amount: transactionVM.thisMonthExpense,
                icon: "arrow.down.circle.fill",
                tint: ZColor.expense
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func incomeExpenseChip(label: String, amount: Double, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .eliteFont(size: 22, weight: .regular, textStyle: .body)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .eliteMicroLabel()
                    .foregroundStyle(ThemeColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .lineLimit(1)
                Text(amount.formattedCurrency(code: transactionVM.primaryCurrency))
                    .eliteFont(size: 15, weight: .bold, textStyle: .body)
                    .foregroundStyle(ThemeColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 24)
    }

    // MARK: - Quick Actions ────────────────────────────────────────────

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localizer.shared.l("dashboard.quickActions"))
                .eliteMicroLabel()
                .foregroundStyle(ThemeColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.leading, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Gider Ekle
                    quickActionButton(
                        icon: "minus.circle.fill",
                        label: Localizer.shared.l("dashboard.expense"),
                        color: ZColor.expense
                    ) { onAddTapped() }

                    // Gelir Ekle
                    quickActionButton(
                        icon: "plus.circle.fill",
                        label: Localizer.shared.l("dashboard.income"),
                        color: ZColor.income
                    ) { onAddTapped() }

                    // AI Analiz
                    quickActionButton(
                        icon: "sparkles",
                        label: Localizer.shared.l("dashboard.insights"),
                        color: Color(hex: appThemeColorHex)
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showInsights.toggle()
                        }
                        Haptic.light()
                    }

                    // Takvim
                    quickActionButton(
                        icon: "calendar",
                        label: Localizer.shared.l("tab.calendar"),
                        color: Color(hex: "#0A84FF")
                    ) { selectedTab = 3 }

                    // Raporlar
                    quickActionButton(
                        icon: "chart.bar.xaxis",
                        label: Localizer.shared.l("tab.reports"),
                        color: ZColor.purple
                    ) { selectedTab = 1 }

                    // Ödemeler
                    quickActionButton(
                        icon: "calendar.badge.clock",
                        label: Localizer.shared.l("payment.upcoming"),
                        color: ZColor.warning
                    ) { selectedTab = 3 }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private func quickActionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button { action(); Haptic.light() } label: {
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(color.opacity(0.14))
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(color.opacity(0.22), lineWidth: 0.8)
                        )
                        .shadow(color: color.opacity(0.15), radius: 8, y: 4)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(color)
                }

                Text(label)
                    .eliteFont(size: 11, weight: .medium, textStyle: .caption)
                    .foregroundStyle(ThemeColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 66)
            }
        }
        .buttonStyle(.plain)
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
        guard let pct = transactionVM.expenseChangePercent else { return "—" }
        return "\(pct >= 0 ? "+" : "")\(String(format: "%.1f", pct))%"
    }

    private var expenseChangeColor: Color {
        guard let pct = transactionVM.expenseChangePercent else { return ZColor.labelSec }
        return pct >= 0 ? ZColor.expense : ZColor.income
    }

    // MARK: - AI Insights Section

    private var aiInsightsSection: some View {
        VStack(spacing: 10) {
            SectionHeader(
                title: NSLocalizedString("dashboard.insights", comment: ""),
                trailing: showInsights
                    ? NSLocalizedString("dashboard.showLess", comment: "")
                    : NSLocalizedString("dashboard.showMore", comment: "")) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showInsights.toggle()
                }
                Haptic.selection()
            }

            let displayed = showInsights ? insights : Array(insights.prefix(2))
            ForEach(displayed) { insight in
                AIInsightCard(insight: insight) {
                    if insight.type == .upcoming || insight.actionLabel == "Takvime Git" {
                        selectedTab = 3
                    } else if insight.actionLabel == NSLocalizedString("action.addTransaction", comment: "") || insight.actionLabel == "İşlem Ekle" {
                        onAddTapped()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity))
            }
        }
    }

    // MARK: - Budget Tracker

    @ViewBuilder
    private var budgetSection: some View {
        // Sort by spending ratio desc — most active/critical first
        let allCats = transactionVM.categories
            .filter { budgetManager.budgets[$0.id] != nil }
            .sorted {
                let lim0 = budgetManager.budgets[$0.id] ?? 1
                let lim1 = budgetManager.budgets[$1.id] ?? 1
                let r0 = lim0 > 0 ? transactionVM.categorySpending(categoryId: $0.id) / lim0 : 0
                let r1 = lim1 > 0 ? transactionVM.categorySpending(categoryId: $1.id) / lim1 : 0
                return r0 > r1
            }
        let visibleCats = Array(allCats.prefix(showAllBudgets ? allCats.count : 4))
        let hasMore = allCats.count > 4

        if !allCats.isEmpty {
            VStack(spacing: 10) {
                SectionHeader(title: NSLocalizedString("dashboard.budgets", comment: ""))

                VStack(spacing: 0) {
                    ForEach(Array(visibleCats.enumerated()), id: \.element.id) { idx, cat in
                        let limit = budgetManager.budgets[cat.id] ?? 0
                        let spent = transactionVM.categorySpending(categoryId: cat.id)
                        let ratio = limit > 0 ? spent / limit : 0

                        budgetRow(cat: cat, spent: spent, limit: limit, ratio: ratio)

                        if idx < visibleCats.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }

                    if hasMore {
                        Divider().padding(.horizontal, 14)
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showAllBudgets.toggle()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(showAllBudgets
                                     ? NSLocalizedString("common.showLess", comment: "Show less")
                                     : String(format: NSLocalizedString("common.showMoreCount", comment: "+%d more"), allCats.count - 4))
                                    .eliteFont(size: 13, weight: .semibold, textStyle: .caption)
                                    .foregroundStyle(ThemeColors.textSecondary)
                                Image(systemName: showAllBudgets ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ThemeColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .liquidGlass(cornerRadius: 24)
            }
        }
    }

    private func budgetRow(cat: Category, spent: Double, limit: Double, ratio: Double) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: cat.color).opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: cat.icon ?? "circle")
                        .eliteFont(size: 14, weight: .medium, textStyle: .body)
                        .foregroundStyle(Color(hex: cat.color))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(cat.localizedName)
                        .eliteFont(size: 14, weight: .medium, textStyle: .body)
                        .foregroundStyle(ThemeColors.textPrimary)
                        .lineLimit(1)
                    Text("\(spent.formattedShort(code: transactionVM.primaryCurrency)) / \(limit.formattedShort(code: transactionVM.primaryCurrency))")
                        .eliteCaption()
                        // eliteCaption already applies ThemeColors.textSecondary
                }

                Spacer()

                Text("\(Int(min(ratio * 100, 100)))%")
                    .eliteFont(size: 12, weight: .semibold, textStyle: .caption)
                    .foregroundStyle(budgetStatusColor(ratio: ratio))
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

    // MARK: - Goals Preview

    private var goalsPreviewSection: some View {
        let activeGoals = goalVM.goals.filter { !$0.isComplete }.prefix(3)
        return Group {
            if !activeGoals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("FİNANSAL HEDEFLER")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            showGoalsSheet = true
                        } label: {
                            Text("Tümünü Gör")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.baseColor)
                        }
                    }
                    .padding(.horizontal, 4)

                    GlassCard(cornerRadius: 20) {
                        VStack(spacing: 0) {
                            ForEach(Array(activeGoals.enumerated()), id: \.element.id) { idx, goal in
                                VStack(spacing: 8) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: goal.colorHex).opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: goal.icon)
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(hex: goal.colorHex))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(goal.title)
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("\(goal.currentAmount.formattedShort()) / \(goal.targetAmount.formattedShort())")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("\(Int(goal.percentage))%")
                                            .font(.system(size: 13, weight: .black))
                                            .foregroundColor(Color(hex: goal.colorHex))
                                    }
                                    ProgressView(value: min(goal.percentage / 100.0, 1.0))
                                        .tint(Color(hex: goal.colorHex))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                if idx < activeGoals.count - 1 {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showGoalsSheet) {
                    GoalsView()
                        .environmentObject(authVM)
                        .environmentObject(goalVM)
                }
            }
        }
    }

    // MARK: - Cash Flow Preview

    private var cashFlowPreviewSection: some View {
        let upcomingScheduled = scheduledPaymentVM.pendingPayments.filter {
            let today = Calendar.current.startOfDay(for: Date())
            let scheduled = Calendar.current.startOfDay(for: $0.scheduledDate)
            if let days = Calendar.current.dateComponents([.day], from: today, to: scheduled).day {
                return days > 0 && days <= 7
            }
            return false
        }

        let upcomingRecurring = recurringVM.activeTransactions.filter { $0.isActive }.filter {
            let today = Calendar.current.startOfDay(for: Date())
            let next = Calendar.current.startOfDay(for: $0.nextOccurrence)
            if let days = Calendar.current.dateComponents([.day], from: today, to: next).day {
                return days > 0 && days <= 7
            }
            return false
        }

        return Group {
            if !upcomingScheduled.isEmpty || !upcomingRecurring.isEmpty {
                VStack(spacing: 10) {
                    SectionHeader(
                        title: NSLocalizedString("dashboard.cashFlow", comment: ""),
                        trailing: "7 gün") {
                        selectedTab = 4
                        Haptic.light()
                    }

                    GlassCard(cornerRadius: 20) {
                        VStack(spacing: 0) {
                            ForEach(Array(upcomingScheduled.prefix(5).enumerated()), id: \.element.id) { idx, payment in
                                HStack(spacing: 12) {
                                    Image(systemName: payment.type == "income" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundColor(payment.type == "income" ? ZColor.income : ZColor.expense)
                                        .font(.system(size: 18))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(payment.title)
                                            .eliteFont(size: 13, weight: .semibold, textStyle: .body)
                                        Text(payment.scheduledDate, style: .date)
                                            .eliteCaption()
                                    }

                                    Spacer()

                                    Text(payment.amount.formattedCurrency(code: payment.currency))
                                        .eliteFont(size: 12, weight: .bold, textStyle: .body)
                                        .foregroundColor(payment.type == "income" ? ZColor.income : ZColor.expense)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                if idx < upcomingScheduled.prefix(5).count - 1 {
                                    Divider().padding(.leading, 50)
                                }
                            }

                            ForEach(Array(upcomingRecurring.prefix(5 - upcomingScheduled.count).enumerated()), id: \.element.id) { idx, payment in
                                HStack(spacing: 12) {
                                    Image(systemName: payment.transactionType == "income" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundColor(payment.transactionType == "income" ? ZColor.income : ZColor.expense)
                                        .font(.system(size: 18))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(payment.title)
                                            .eliteFont(size: 13, weight: .semibold, textStyle: .body)
                                        Text(payment.nextOccurrence, style: .date)
                                            .eliteCaption()
                                    }

                                    Spacer()

                                    Text((payment.expectedAmount ?? 0).formattedCurrency(code: payment.currency))
                                        .eliteFont(size: 12, weight: .bold, textStyle: .body)
                                        .foregroundColor(payment.transactionType == "income" ? ZColor.income : ZColor.expense)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                if idx < upcomingRecurring.prefix(5 - upcomingScheduled.count).count - 1 {
                                    Divider().padding(.leading, 50)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Scheduled Payments Widget

    @ViewBuilder
    private var scheduledPaymentsSection: some View {
        // Priority 1: Ready to be approved
        if !scheduledPaymentVM.readyPayments.isEmpty {
            VStack(spacing: 8) {
                ForEach(scheduledPaymentVM.readyPayments) { payment in
                    ReadyPaymentCard(
                        payment: payment,
                        onApprove: {
                            Task {
                                guard let userId = authVM.currentUserId else { return }
                                let confirmed = await scheduledPaymentVM.confirmPayment(
                                    payment: payment,
                                    transactionVM: transactionVM,
                                    userId: userId
                                )
                                if confirmed { Haptic.success() }
                            }
                        },
                        onReject: {
                            Task {
                                await scheduledPaymentVM.cancelPayment(paymentId: payment.id)
                                Haptic.light()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        
        // Priority 2: Upcoming (Pending) within next 3 days
        let upcoming = scheduledPaymentVM.pendingPayments.filter {
            let today = Calendar.current.startOfDay(for: Date())
            let scheduled = Calendar.current.startOfDay(for: $0.scheduledDate)
            if let days = Calendar.current.dateComponents([.day], from: today, to: scheduled).day {
                return days > 0 && days <= 3
            }
            return false
        }
        
        if !upcoming.isEmpty {
            VStack(spacing: 12) {
                ForEach(upcoming.prefix(2)) { payment in
                    let daysLeft = Calendar.current.dateComponents(
                        [.day],
                        from: Calendar.current.startOfDay(for: Date()),
                        to: Calendar.current.startOfDay(for: payment.scheduledDate)
                    ).day ?? 0
                    // Urgency: 1 day = orange, 2-3 days = amber
                    let urgencyColor: Color = daysLeft <= 1 ? ZColor.warning : ZColor.amber

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(urgencyColor.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "calendar.badge.clock")
                                .eliteFont(size: 17, weight: .medium, textStyle: .body)
                                .foregroundStyle(urgencyColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Localizer.shared.l("payment.upcoming"))
                                .eliteMicroLabel()
                                .foregroundStyle(urgencyColor)
                            Text(payment.title)
                                .eliteFont(size: 14, weight: .semibold, textStyle: .body)
                                .foregroundStyle(ThemeColors.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(payment.amount.formattedCurrency(code: payment.currency))
                                .eliteFont(size: 14, weight: .bold, textStyle: .body)
                                .foregroundStyle(ThemeColors.textPrimary)
                            Text(payment.scheduledDate, style: .relative)
                                .eliteCaption()
                        }
                    }
                    .padding(14)
                    .background(urgencyColor.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(urgencyColor.opacity(0.35), lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    // MARK: - Recent Transactions (List-based for swipe support)

    private var recentSection: some View {
        VStack(spacing: 10) {
            SectionHeader(
                title: NSLocalizedString("dashboard.recent", comment: ""),
                trailing: NSLocalizedString("dashboard.seeAll", comment: "")
            ) {
                onSeeAllTransactions()
                Haptic.selection()
            }

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
                .liquidGlass(cornerRadius: 24)
            } else {
                RecentTransactionsListView(
                    transactions: Array(transactionVM.transactions.prefix(5)),
                    transactionVM: transactionVM,
                    onSelect: { selectedTransaction = $0 },
                    onDelete: { transactionToDelete = $0 },
                    onEdit: { transactionToEdit = $0 }
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

    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingTitle)
                    .eliteSubheading()
                    .foregroundStyle(ThemeColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                // Tarih — takvim ikonu ile
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThemeColors.textSecondary.opacity(0.70))
                    Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                        .eliteCaption()
                }
            }

            Spacer()

            // Avatar — HIG 44×44pt, accent ring
            Button { showEditProfile = true; Haptic.light() } label: {
                if let data = authVM.userAvatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(
                                Color(hex: appThemeColorHex).opacity(0.40), lineWidth: 1.5))
                } else {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentGradient)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: appThemeColorHex).opacity(0.35), radius: 8, y: 4)
                        Text(authVM.userProfile?.initials ?? "Z")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
}

// MARK: - AI Insight Card

struct AIInsightCard: View {
    let insight: FinancialInsight
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(insight.type.color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: insight.icon)
                    .eliteFont(size: 17, weight: .semibold, textStyle: .body)
                    .foregroundStyle(insight.type.color)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(insight.title)
                    .eliteFont(size: 14, weight: .bold, textStyle: .body)
                    .foregroundStyle(ThemeColors.textPrimary)
                    .lineLimit(1)

                Text(insight.message.markdownBold())
                    .eliteCallout()
                    .foregroundStyle(ThemeColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let label = insight.actionLabel {
                    Button {
                        onAction()
                        Haptic.light()
                    } label: {
                        Text(label)
                            .eliteFont(size: 13, weight: .bold, textStyle: .callout)
                            .foregroundStyle(insight.type.color)
                            .padding(.vertical, 6)
                            .padding(.trailing, 8)
                            .contentShape(Rectangle()) // Larger touch area
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isButton)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(insight.type.bgColor.opacity(0.3))
        .liquidGlass(cornerRadius: 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - String Markdown Bold Helper

extension String {
    func markdownBold() -> AttributedString {
        var result = AttributedString()
        var remaining = self
        while let start = remaining.range(of: "**") {
            let before = String(remaining[remaining.startIndex..<start.lowerBound])
            result += AttributedString(before)
            remaining = String(remaining[start.upperBound...])
            if let end = remaining.range(of: "**") {
                var bold = AttributedString(String(remaining[remaining.startIndex..<end.lowerBound]))
                bold.font = .system(size: 13, weight: .bold)
                result += bold
                remaining = String(remaining[end.upperBound...])
            } else {
                result += AttributedString("**\(remaining)")
                remaining = ""
            }
        }
        result += AttributedString(remaining)
        return result
    }
}

// MARK: - Recent Transactions List (Extracted for performance)

struct RecentTransactionsListView: View {
    let transactions: [Transaction]
    let transactionVM: TransactionViewModel
    let onSelect: (Transaction) -> Void
    let onDelete: (Transaction) -> Void
    let onEdit: (Transaction) -> Void

    @Environment(\.colorScheme) private var scheme
    @AppStorage("profileCardColor") private var appThemeColorHex: String = "#5E5CE6"

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(transactions.enumerated()), id: \.element.id) { idx, txn in
                TransactionRow(
                    transaction: txn,
                    category: transactionVM.category(for: txn.categoryId)
                )
                .contentShape(Rectangle())
                .onTapGesture { onSelect(txn); Haptic.light() }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        onDelete(txn)
                        Haptic.medium()
                    } label: {
                        Label(NSLocalizedString("common.delete", comment: ""), systemImage: "trash.fill")
                    }
                    Button {
                        onEdit(txn)
                        Haptic.light()
                    } label: {
                        Label(NSLocalizedString("common.edit", comment: ""), systemImage: "pencil")
                    }
                    .tint(Color(hex: appThemeColorHex))
                }
                
                if idx < transactions.count - 1 {
                    Divider().padding(.leading, 70)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ZColor.fillQuart)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5)
        )
    }
}

// MARK: - Scroll Offset Tracking

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
