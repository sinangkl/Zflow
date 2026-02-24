import SwiftUI
import Charts

// MARK: - Unified Transactions + Reports View (Madde 9 & 4)
// Elegant segment switch: List ↔ Reports

struct TransactionsReportsView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) var scheme
    @State private var segment = 0  // 0 = Transactions  1 = Reports

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PremiumBackground()

                VStack(spacing: 0) {
                    // Segment pill — glass style
                    segmentControl
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 6)

                    // Content
                    if segment == 0 {
                        TransactionListContent()
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)))
                    } else {
                        ReportsContent()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
            }
            .navigationTitle(segment == 0
                             ? NSLocalizedString("tab.transactions", comment: "")
                             : NSLocalizedString("reports.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: segment)
    }

    // MARK: - Segment Control

    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach([
                (0, "list.bullet.rectangle.fill", NSLocalizedString("tab.transactions", comment: "")),
                (1, "chart.pie.fill", NSLocalizedString("reports.title", comment: "")),
            ], id: \.0) { idx, icon, label in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { segment = idx }
                    Haptic.selection()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(label)
                            .font(.system(size: 14, weight: segment == idx ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        segment == idx
                        ? RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(scheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.96))
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                        : Color.clear
                    )
                    .foregroundColor(segment == idx
                                     ? (scheme == .dark ? .white : ZColor.label)
                                     : ZColor.labelSec)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(scheme == .dark ? Color.white.opacity(0.07) : Color(.tertiarySystemFill))
        )
    }
}

// MARK: - Transaction List Content

struct TransactionListContent: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) var scheme

    @State private var searchText       = ""
    @State private var filterType: TransactionType?   = nil
    @State private var filterCategoryId: UUID?        = nil
    @State private var sortOrder: SortOrder           = .dateDesc
    @State private var transactionToDelete: Transaction?
    @State private var transactionToEdit: Transaction?
    @State private var showFilters      = false

    enum SortOrder: String, CaseIterable {
        case dateDesc   = "Newest"
        case dateAsc    = "Oldest"
        case amountDesc = "Highest"
        case amountAsc  = "Lowest"
        var localizedName: String {
            switch self {
            case .dateDesc:   return NSLocalizedString("sort.newest", comment: "")
            case .dateAsc:    return NSLocalizedString("sort.oldest", comment: "")
            case .amountDesc: return NSLocalizedString("sort.highest", comment: "")
            case .amountAsc:  return NSLocalizedString("sort.lowest", comment: "")
            }
        }
    }

    private var filtered: [Transaction] {
        var r = transactionVM.transactions
        if let f = filterType { r = r.filter { $0.type == f.rawValue } }
        if let cid = filterCategoryId { r = r.filter { $0.categoryId == cid } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            r = r.filter { t in
                let cat  = transactionVM.category(for: t.categoryId)?.name ?? ""
                let note = t.note ?? ""
                return cat.lowercased().contains(q) || note.lowercased().contains(q)
                    || t.amount.formattedCurrency(code: t.currency).contains(q)
            }
        }
        switch sortOrder {
        case .dateDesc:   return r.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        case .dateAsc:    return r.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        case .amountDesc: return r.sorted { $0.amount > $1.amount }
        case .amountAsc:  return r.sorted { $0.amount < $1.amount }
        }
    }

    private var groupedByDate: [(key: String, items: [Transaction])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filtered) { txn -> String in
            guard let d = txn.date else { return "Unknown" }
            if cal.isDateInToday(d)     { return NSLocalizedString("time.today", comment: "") }
            if cal.isDateInYesterday(d) { return NSLocalizedString("time.yesterday", comment: "") }
            return d.formatted(.dateTime.month(.wide).year())
        }
        return grouped
            .sorted { a, b in
                let aDate = grouped[a.key]?.compactMap { $0.date }.max() ?? .distantPast
                let bDate = grouped[b.key]?.compactMap { $0.date }.max() ?? .distantPast
                return aDate > bDate
            }
            .map { (key: $0.key, items: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search + filter bar
            filterBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            if transactionVM.isLoading {
                loadingSkeletons
            } else if filtered.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                        ForEach(groupedByDate, id: \.key) { group in
                            Section {
                                transactionGroup(group.items)
                            } header: {
                                groupHeader(group.key, items: group.items)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 130)
                }
            }
        }
        .confirmationDialog(
            NSLocalizedString("common.delete", comment: ""),
            isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }),
            titleVisibility: .visible) {
            Button(NSLocalizedString("common.delete", comment: ""), role: .destructive) {
                if let txn = transactionToDelete, let uid = authVM.currentUserId {
                    Task { await transactionVM.deleteTransaction(id: txn.id, userId: uid) }
                }
                transactionToDelete = nil
            }
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {
                transactionToDelete = nil
            }
        }
        .sheet(item: $transactionToEdit) { txn in
            EditTransactionView(transaction: txn)
                .environmentObject(transactionVM)
                .environmentObject(authVM)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 10) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ZColor.labelSec)
                TextField(NSLocalizedString("common.search", comment: ""), text: $searchText)
                    .font(.system(size: 15))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ZColor.labelTert)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.08) : Color(.tertiarySystemFill))
            )

            // Filter
            Button {
                withAnimation { showFilters.toggle() }
                Haptic.selection()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(showFilters ? ZColor.indigo : ZColor.labelSec)
                    .frame(width: 40, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(showFilters
                                  ? ZColor.indigo.opacity(0.12)
                                  : (scheme == .dark ? Color.white.opacity(0.08) : Color(.tertiarySystemFill)))
                    )
            }

            // Sort menu
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        withAnimation { sortOrder = order }
                    } label: {
                        Label(order.localizedName,
                              systemImage: sortOrder == order ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ZColor.labelSec)
                    .frame(width: 40, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(scheme == .dark ? Color.white.opacity(0.08) : Color(.tertiarySystemFill))
                    )
            }
        }
    }

    // MARK: - Group Header

    private func groupHeader(_ title: String, items: [Transaction]) -> some View {
        let total = items.filter { $0.type == "expense" }.reduce(0.0) {
            $0 + transactionVM.convert($1)
        }
        return HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ZColor.labelSec)
            Spacer()
            if total > 0 {
                Text("−" + total.formattedShort(code: transactionVM.primaryCurrency))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ZColor.expense.opacity(0.80))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .background(
            scheme == .dark
                ? AnyShapeStyle(Color(hex: "#000000").opacity(0.01))
                : AnyShapeStyle(Color(.systemGroupedBackground))
        )
    }

    // MARK: - Transaction Group

    private func transactionGroup(_ items: [Transaction]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, txn in
                let cat = transactionVM.category(for: txn.categoryId)

                EnhancedTransactionRow(transaction: txn, category: cat)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            transactionToDelete = txn
                        } label: {
                            Label(NSLocalizedString("common.delete", comment: ""),
                                  systemImage: "trash.fill")
                        }

                        Button {
                            transactionToEdit = txn
                            Haptic.light()
                        } label: {
                            Label(NSLocalizedString("common.edit", comment: ""),
                                  systemImage: "pencil")
                        }
                        .tint(ZColor.indigo)
                    }
                    .contextMenu {
                        Button {
                            transactionToEdit = txn
                        } label: {
                            Label(NSLocalizedString("common.edit", comment: ""), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            transactionToDelete = txn
                        } label: {
                            Label(NSLocalizedString("common.delete", comment: ""), systemImage: "trash")
                        }
                    }

                if idx < items.count - 1 {
                    Divider().padding(.leading, 70)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5)
        )
    }

    // MARK: - Loading & Empty

    private var loadingSkeletons: some View {
        VStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { _ in
                ShimmerView(height: 64, cornerRadius: 12)
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "tray",
            title: NSLocalizedString("dashboard.noTransactions", comment: ""),
            message: NSLocalizedString("dashboard.addFirst", comment: ""))
        .padding(.horizontal, 16)
    }
}

// MARK: - Enhanced Transaction Row
// Category rengi öne çıkan, elit görünüm

struct EnhancedTransactionRow: View {
    let transaction: Transaction
    let category: Category?
    @Environment(\.colorScheme) var scheme

    private var isIncome: Bool { transaction.type == "income" }
    private var catColor: Color { Color(hex: category?.color ?? "#8E8E93") }

    var body: some View {
        HStack(spacing: 14) {
            // Category icon — iOS 26 glass tile
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(catColor.opacity(0.14))
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(catColor.opacity(0.22), lineWidth: 0.5)
                    )

                Image(systemName: category?.icon ?? "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [catColor, catColor.opacity(0.75)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            // Details
            VStack(alignment: .leading, spacing: 3) {
                Text(category?.name ?? NSLocalizedString("category.other", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ZColor.label)

                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundColor(ZColor.labelSec)
                        .lineLimit(1)
                } else if let date = transaction.date {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 13))
                        .foregroundColor(ZColor.labelSec)
                }
            }

            Spacer()

            // Amount + date
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(isIncome ? "+" : "−")\(transaction.amount.formattedCurrency(code: transaction.currency))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isIncome ? ZColor.income : ZColor.expense)

                if let date = transaction.date {
                    Text(date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 12))
                        .foregroundColor(ZColor.labelTert)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Reports Content
// Elite charts, per-category colors

struct ReportsContent: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.colorScheme) var scheme

    @State private var selectedPeriod: Period       = .month
    @State private var selectedType: TransactionType = .expense

    enum Period: String, CaseIterable {
        case week = "7D", month = "30D", quarter = "90D", year = "1Y"
        var days: Int {
            switch self { case .week: 7; case .month: 30; case .quarter: 90; case .year: 365 }
        }
        var localizedName: String { rawValue }
    }

    private var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date()) ?? Date()
    }

    private var filteredTotal: Double {
        transactionsFiltered(type: selectedType, from: startDate)
            .reduce(0) { $0 + transactionVM.convert($1) }
    }

    private var breakdown: [(category: Category?, total: Double, percent: Double)] {
        transactionVM.categoryBreakdown(type: selectedType.rawValue, from: startDate)
    }

    private var dailyData: [(date: Date, total: Double)] {
        transactionVM.dailyTotals(type: selectedType.rawValue, from: startDate)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Period + type controls
                controlRow

                // Hero total
                totalHero

                // Trend chart
                if !dailyData.isEmpty { trendCard }

                // Donut
                if !breakdown.isEmpty { donutCard }

                // Category breakdown list
                if !breakdown.isEmpty { categoryBreakdownCard }

                // Month comparison
                comparisonCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 130)
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        VStack(spacing: 10) {
            // Period pills
            HStack(spacing: 6) {
                ForEach(Period.allCases, id: \.self) { p in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { selectedPeriod = p }
                        Haptic.selection()
                    } label: {
                        Text(p.localizedName)
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Group {
                                    if selectedPeriod == p {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(AppTheme.accentGradient)
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(scheme == .dark
                                                  ? Color.white.opacity(0.07)
                                                  : Color(.tertiarySystemFill))
                                    }
                                }
                            )
                            .foregroundColor(selectedPeriod == p ? .white : ZColor.labelSec)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.05) : Color(.secondarySystemGroupedBackground))
            )

            // Type toggle
            HStack(spacing: 8) {
                typeToggleButton(.income, ZColor.income)
                typeToggleButton(.expense, ZColor.expense)
            }
        }
    }

    private func typeToggleButton(_ type: TransactionType, _ color: Color) -> some View {
        let sel = selectedType == type
        let label = type == .income
            ? NSLocalizedString("dashboard.income", comment: "")
            : NSLocalizedString("dashboard.expense", comment: "")
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { selectedType = type }
            Haptic.selection()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(sel ? color : color.opacity(0.35))
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 14, weight: sel ? .bold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(sel
                          ? color.opacity(0.12)
                          : (scheme == .dark ? Color.white.opacity(0.06) : Color(.tertiarySystemFill)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(sel ? color.opacity(0.45) : .clear, lineWidth: 1.5)
            )
            .foregroundColor(sel ? color : ZColor.labelSec)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero Total

    private var totalHero: some View {
        let gradient = selectedType == .income ? AppTheme.incomeGradient : AppTheme.expenseGradient
        return GradientCard(gradient: gradient, cornerRadius: 20) {
            VStack(spacing: 10) {
                Text(selectedType == .income
                     ? NSLocalizedString("reports.totalIncome", comment: "")
                     : NSLocalizedString("reports.totalExpense", comment: ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    .textCase(.uppercase)
                    .tracking(0.4)

                Text(filteredTotal.formattedCurrency(code: transactionVM.primaryCurrency))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.80), value: filteredTotal)

                Text("\(transactionsFiltered(type: selectedType, from: startDate).count) " +
                     NSLocalizedString("dashboard.transactions", comment: "") + " · " +
                     selectedPeriod.localizedName)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
        }
    }

    // MARK: - Trend Chart

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("reports.trend", comment: ""))
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(ZColor.label)

            let color = selectedType == .income ? ZColor.income : ZColor.expense
            Chart(dailyData, id: \.date) { pt in
                LineMark(
                    x: .value("Date", pt.date),
                    y: .value("Amount", pt.total))
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", pt.date),
                    y: .value("Amount", pt.total))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.28), .clear],
                        startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .stride(by: .day, count: max(1, selectedPeriod.days / 5))) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated),
                                   centered: false)
                    .font(.system(size: 10))
                    .foregroundStyle(ZColor.labelTert)
                }
            }
            .chartYAxis {
                AxisMarks { val in
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text(v.formattedShort(code: ""))
                                .font(.system(size: 10))
                                .foregroundStyle(ZColor.labelTert)
                        }
                    }
                    AxisGridLine().foregroundStyle(ZColor.labelQuart)
                }
            }
            .frame(height: 160)
        }
        .padding(18)
        .zFlowCard()
    }

    // MARK: - Donut Chart

    private var donutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("reports.breakdown", comment: ""))
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(ZColor.label)

            HStack(spacing: 20) {
                // Donut
                Chart(breakdown.prefix(8), id: \.total) { item in
                    SectorMark(
                        angle: .value("Percent", item.percent),
                        innerRadius: .ratio(0.58),
                        angularInset: 2)
                    .foregroundStyle(Color(hex: item.category?.color ?? "#8E8E93"))
                    .cornerRadius(4)
                }
                .frame(width: 130, height: 130)

                // Legend
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(breakdown.prefix(5), id: \.total) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: item.category?.color ?? "#8E8E93"))
                                .frame(width: 9, height: 9)
                            Text(item.category?.name ?? NSLocalizedString("category.other", comment: ""))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ZColor.label)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(item.percent))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: item.category?.color ?? "#8E8E93"))
                        }
                    }
                }
            }
        }
        .padding(18)
        .zFlowCard()
    }

    // MARK: - Category Breakdown List

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("reports.topCategories", comment: ""))
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(ZColor.label)

            VStack(spacing: 0) {
                ForEach(Array(breakdown.enumerated()), id: \.offset) { idx, item in
                    let color = Color(hex: item.category?.color ?? "#8E8E93")
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            // Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(color.opacity(0.14))
                                    .frame(width: 36, height: 36)
                                Image(systemName: item.category?.icon ?? "circle")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [color, color.opacity(0.7)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.category?.name ?? NSLocalizedString("category.other", comment: ""))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(ZColor.label)
                                Text("\(Int(item.percent))% of total")
                                    .font(.system(size: 11))
                                    .foregroundColor(ZColor.labelSec)
                            }

                            Spacer()

                            Text(item.total.formattedCurrency(code: transactionVM.primaryCurrency))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(color)
                        }

                        // Progress bar with category color
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(color.opacity(0.12))
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [color, color.opacity(0.7)],
                                            startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * (item.percent / 100), height: 5)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: item.percent)
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)

                    if idx < breakdown.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Comparison Card

    private var comparisonCard: some View {
        let current  = transactionVM.thisMonthExpense
        let previous = transactionVM.lastMonthExpense
        let diff     = current - previous
        let pct      = previous > 0 ? (diff / previous) * 100 : 0

        return VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("reports.comparison", comment: ""))
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(ZColor.label)

            HStack(spacing: 16) {
                comparisonItem(
                    label: NSLocalizedString("reports.thisMonth", comment: ""),
                    value: current,
                    color: ZColor.expense)
                Rectangle()
                    .fill(AppTheme.cardBorder(for: scheme))
                    .frame(width: 0.5)
                comparisonItem(
                    label: NSLocalizedString("reports.lastMonth", comment: ""),
                    value: previous,
                    color: ZColor.labelSec)
            }

            HStack(spacing: 6) {
                Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.left")
                    .font(.system(size: 11, weight: .bold))
                Text("\(diff >= 0 ? "+" : "")\(String(format: "%.1f", pct))% vs last month")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(diff >= 0 ? ZColor.expense : ZColor.income)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((diff >= 0 ? ZColor.expense : ZColor.income).opacity(0.10))
            )
        }
        .padding(18)
        .zFlowCard()
    }

    private func comparisonItem(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ZColor.labelSec)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value.formattedCurrency(code: transactionVM.primaryCurrency))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func transactionsFiltered(type: TransactionType, from start: Date) -> [Transaction] {
        transactionVM.transactions.filter {
            $0.type == type.rawValue && ($0.date ?? .distantPast) >= start
        }
    }
}
