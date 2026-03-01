import SwiftUI

struct AllTransactionsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.colorScheme) var scheme

    @State private var searchText           = ""
    @State private var filterType: TransactionType? = nil
    @State private var filterCategoryId: UUID?      = nil
    @State private var sortOrder: SortOrder         = .dateDesc
    @State private var transactionToDelete: Transaction?
    @State private var transactionToEdit: Transaction?
    @State private var showFilters          = false

    enum SortOrder: String, CaseIterable {
        case dateDesc  = "Newest"
        case dateAsc   = "Oldest"
        case amountDesc = "Highest"
        case amountAsc  = "Lowest"
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
            if cal.isDateInToday(d)     { return "Today" }
            if cal.isDateInYesterday(d) { return "Yesterday" }
            return d.formatted(.dateTime.month(.wide).year())
        }
        // Sort groups: Today first, then Yesterday, then months desc
        let order = ["Today", "Yesterday"]
        return grouped.sorted { a, b in
            let ai = order.firstIndex(of: a.key) ?? Int.max
            let bi = order.firstIndex(of: b.key) ?? Int.max
            if ai != bi { return ai < bi }
            return a.key > b.key
        }.map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                VStack(spacing: 0) {
                    // Filter chips
                    filterBar
                        .padding(.top, 4)

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        // Summary strip
                        summaryStrip
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                        List {
                            ForEach(groupedByDate, id: \.key) { group in
                                Section {
                                    ForEach(group.items) { txn in
                                        TransactionRow(
                                            transaction: txn,
                                            category: transactionVM.category(for: txn.categoryId))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                transactionToDelete = txn; Haptic.medium()
                                            } label: { Label("Delete", systemImage: "trash.fill") }

                                            Button {
                                                transactionToEdit = txn; Haptic.light()
                                            } label: { Label("Edit", systemImage: "pencil") }
                                            .tint(ZColor.indigo)
                                        }
                                    }
                                } header: {
                                    Text(group.key)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search transactions…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Sort By") {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button {
                                    sortOrder = order; Haptic.selection()
                                } label: {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ZColor.indigo)
                    }
                    .accessibilityLabel("Sort transactions")
                }
            }
            .sheet(item: $transactionToEdit) { txn in
                EditTransactionView(transaction: txn)
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
            .alert("Delete Transaction?", isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let t = transactionToDelete, let uid = authVM.currentUserId {
                        Task { await transactionVM.deleteTransaction(id: t.id, userId: uid) }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PillTag(label: "All", color: ZColor.indigo, isSelected: filterType == nil) {
                    withAnimation { filterType = nil; filterCategoryId = nil }
                    Haptic.selection()
                }
                PillTag(label: "Income", color: ZColor.income,
                        isSelected: filterType == .income) {
                    withAnimation { filterType = filterType == .income ? nil : .income }
                    Haptic.selection()
                }
                PillTag(label: "Expense", color: ZColor.expense,
                        isSelected: filterType == .expense) {
                    withAnimation { filterType = filterType == .expense ? nil : .expense }
                    Haptic.selection()
                }
                // Category filters
                ForEach(transactionVM.categories.prefix(5)) { cat in
                    PillTag(
                        label: cat.name,
                        color: Color(hex: cat.color),
                        isSelected: filterCategoryId == cat.id) {
                        withAnimation {
                            filterCategoryId = filterCategoryId == cat.id ? nil : cat.id
                        }
                        Haptic.selection()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        let income  = filtered.filter { $0.type == "income"  }.reduce(0) { $0 + transactionVM.convert($1) }
        let expense = filtered.filter { $0.type == "expense" }.reduce(0) { $0 + transactionVM.convert($1) }

        return HStack(spacing: 12) {
            summaryChip("+\(income.formattedCurrency(code: transactionVM.primaryCurrency))",
                        color: ZColor.income, icon: "arrow.down.circle.fill")
            summaryChip("-\(expense.formattedCurrency(code: transactionVM.primaryCurrency))",
                        color: ZColor.expense, icon: "arrow.up.circle.fill")
            Spacer()
            Text("\(filtered.count) items")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private func summaryChip(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.1)))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Spacer()
            .overlay(
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: searchText.isEmpty ? "No Transactions" : "No Results",
                    message: searchText.isEmpty
                        ? "Add a transaction using the + button."
                        : "Try a different search term or clear filters.")
            )
    }
}
