import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST
import Realtime

@MainActor
final class TransactionViewModel: ObservableObject {

    // MARK: - Published

    @Published var transactions: [Transaction] = []
    @Published var categories:   [Category]    = []
    @Published var isLoading     = false
    @Published var errorMessage: String?
    @Published var categorySpendingThisMonth: [UUID: Double] = [:]

    @AppStorage("defaultCurrency") var primaryCurrency: String = "TRY"

    private let supabase = SupabaseManager.shared.client

    // Ecosystem: authVM, budgetManager ve scheduledPaymentVM inject edilir
    weak var authVM:              AuthViewModel?
    weak var budgetManager:       BudgetManager?
    weak var scheduledPaymentVM:  ScheduledPaymentViewModel?
    weak var recurringVM:         RecurringTransactionViewModel?
    weak var calMgr:              CalendarManager?

    private var cancellables: Set<AnyCancellable> = []
    private var realtimeChannel: RealtimeChannelV2?

    init() {
        // Refresh widget snapshot whenever budgets change
        NotificationCenter.default
            .publisher(for: BudgetManager.budgetsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateEcosystem() }
            .store(in: &cancellables)
            
        NotificationCenter.default
            .publisher(for: Notification.Name("ZFlowDidLogout"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.clearData() }
            .store(in: &cancellables)
    }
    
    func clearData() {
        stopRealtime()
        transactions.removeAll()
        categories.removeAll()
        categorySpendingThisMonth.removeAll()
        errorMessage = nil
        updateEcosystem()
    }

    // MARK: - Computed: Totals

    var totalIncome: Double  { sumConverted(type: "income") }
    var totalExpense: Double { sumConverted(type: "expense") }
    var netBalance: Double   { totalIncome - totalExpense }

    var thisMonthIncome: Double  { sumConverted(type: "income",  period: .month) }
    var thisMonthExpense: Double { sumConverted(type: "expense", period: .month) }
    var thisMonthNet: Double     { thisMonthIncome - thisMonthExpense }

    var lastMonthExpense: Double { sumConverted(type: "expense", period: .lastMonth) }

    var expenseChangePercent: Double? {
        let last = lastMonthExpense
        guard last > 0 else { return nil }
        return ((thisMonthExpense - last) / last) * 100
    }

    // MARK: - Computed: Category Spending (this month)

    func categorySpending(categoryId: UUID) -> Double {
        return categorySpendingThisMonth[categoryId] ?? 0.0
    }

    /// Belirli bir kategorinin bu ayki gider toplamı
    func categoryExpenseThisMonth(for categoryId: UUID) -> Double {
        let cal = Calendar.current
        let now = Date()
        return transactions.filter {
            guard let d = $0.date else { return false }
            return cal.isDate(d, equalTo: now, toGranularity: .month)
                && $0.type == "expense"
                && $0.categoryId == categoryId
        }.reduce(0) { $0 + convert($1) }
    }

    /// Belirli bir kategorinin geçen ayki gider toplamı
    func categoryExpenseLastMonth(for categoryId: UUID) -> Double {
        let cal = Calendar.current
        let now = Date()
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: now) else { return 0 }
        return transactions.filter {
            guard let d = $0.date else { return false }
            return cal.isDate(d, equalTo: lastMonth, toGranularity: .month)
                && $0.type == "expense"
                && $0.categoryId == categoryId
        }.reduce(0) { $0 + convert($1) }
    }

    // MARK: - Computed: Calendar

    var datesWithTransactions: Set<DateComponents> {
        let cal = Calendar.current
        return Set(transactions.compactMap { txn -> DateComponents? in
            guard let d = txn.date else { return nil }
            return cal.dateComponents([.year, .month, .day], from: d)
        })
    }

    // MARK: - Computed: Category Breakdown

    func categoryBreakdown(type: String, from start: Date) -> [(category: Category?, total: Double, percent: Double)] {
        let filtered = transactions.filter {
            guard let d = $0.date else { return false }
            return d >= start && $0.type == type
        }
        let grand = filtered.reduce(0.0) { $0 + convert($1) }
        let grouped = Dictionary(grouping: filtered) { $0.categoryId }
        return grouped.map { (catId, txns) in
            let total = txns.reduce(0.0) { $0 + convert($1) }
            return (category(for: catId), total, grand > 0 ? (total / grand) * 100 : 0)
        }.sorted { $0.total > $1.total }
    }

    func dailyTotals(type: String, from start: Date) -> [(date: Date, total: Double)] {
        let filtered = transactions.filter {
            guard let d = $0.date else { return false }
            return d >= start && $0.type == type
        }
        let grouped = Dictionary(grouping: filtered) {
            Calendar.current.startOfDay(for: $0.date ?? Date())
        }
        return grouped.map { (d, txns) in (d, txns.reduce(0.0) { $0 + convert($1) }) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Fetch & Refresh

    func refreshData(userId: UUID, userType: String) async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchTransactions(userId: userId) }
            group.addTask { await self.fetchCategories(userId: userId, userType: userType) }
        }
        isLoading = false
        updateEcosystem()
        subscribeToRealtime(userId: userId)
    }

    func stopRealtime() {
        let channel = realtimeChannel
        realtimeChannel = nil
        Task {
            await channel?.unsubscribe()
        }
    }

    func subscribeToRealtime(userId: UUID) {
        guard realtimeChannel == nil else { return }
        
        let channel = supabase.realtimeV2
            .channel("public:transactions:user=\(userId.uuidString)")
        
        realtimeChannel = channel
        
        _ = channel.onPostgresChange(
            AnyAction.self,
            table: "transactions",
            filter: "user_id=eq.\(userId.uuidString)"
        ) { action in
            Task { @MainActor [weak self] in
                self?.handleRealtimeChange(action)
            }
        }
        
        Task {
            do {
                try await channel.subscribeWithError()
            } catch {
                print("❌ [Realtime] Subscribe error: \(error)")
            }
        }
    }

    private func handleRealtimeChange(_ action: AnyAction) {
        print("🔔 [Realtime] Transaction change detected")
        
        let decoder = PostgrestClient.Configuration.jsonDecoder
        switch action {
        case .insert(let a):
            do {
                let newTxn: Transaction = try a.decodeRecord(decoder: decoder)
                if !transactions.contains(where: { $0.id == newTxn.id }) {
                    transactions.insert(newTxn, at: 0)
                    updateEcosystem()
                }
            } catch {
                print("❌ [Realtime] Error decoding inserted transaction: \(error)")
            }
        case .update(let a):
            do {
                let updated: Transaction = try a.decodeRecord(decoder: decoder)
                if let idx = transactions.firstIndex(where: { $0.id == updated.id }) {
                    transactions[idx] = updated
                    updateEcosystem()
                }
            } catch {
                print("❌ [Realtime] Error decoding updated transaction: \(error)")
            }
        case .delete(let a):
            do {
                let old: Transaction = try a.decodeOldRecord(decoder: decoder)
                if let idx = transactions.firstIndex(where: { $0.id == old.id }) {
                    transactions.remove(at: idx)
                    updateEcosystem()
                }
            } catch {
                print("❌ [Realtime] Error decoding deleted transaction: \(error)")
            }
        }
    }

    func fetchTransactions(userId: UUID) async {
        do {
            transactions = try await supabase.from("transactions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("date", ascending: false)
                .order("created_at", ascending: false)
                .execute().value
        } catch { errorMessage = error.localizedDescription }
    }

    func fetchCategories(userId: UUID, userType: String) async {
        do {
            print("📂 [Categories] Fetching for user: \(userId.uuidString)")
            let fetched: [Category] = try await supabase.from("categories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("name")
                .execute().value

            print("📂 [Categories] Fetched \(fetched.count) categories")
            if fetched.isEmpty {
                print("📂 [Categories] Empty — seeding defaults for userType: \(userType)")
                await seedDefaultCategories(userId: userId, userType: userType)
            } else {
                var seenNames = Set<String>()
                categories = fetched.filter { cat in
                    guard !seenNames.contains(cat.name) else { return false }
                    seenNames.insert(cat.name)
                    return true
                }
            }
        } catch {
            print("❌ [Categories] FETCH ERROR: \(error)")
            errorMessage = "Kategoriler yüklenirken hata oluştu: \(error.localizedDescription)"
        }
    }

    // MARK: - CRUD: Transactions

    @discardableResult
    func addTransaction(userId: UUID, amount: Double, currency: Currency,
                        type: TransactionType, categoryId: UUID?,
                        note: String?, date: Date, status: String?, attachmentURL: String?) async -> Bool {
        let insert = TransactionInsert(
            userId: userId, amount: amount, currency: currency.rawValue,
            type: type.rawValue,
            categoryId: categoryId,
            note: note?.isEmpty == true ? nil : note,
            date: date,
            status: status,
            attachmentURL: attachmentURL)
        do {
            let result: [Transaction] = try await supabase.from("transactions")
                .insert(insert)
                .select()
                .execute()
                .value
            
            if let newTxn = result.first {
                self.transactions.insert(newTxn, at: 0)
                print("✅ [Transactions] Added and updated local state: \(newTxn.id)")
            } else {
                // Fallback if select() returns empty
                await fetchTransactions(userId: userId)
            }
            
            Haptic.success()
            updateEcosystem()
            return true
        } catch {
            print("❌ [Transactions] ADD ERROR: \(error)")
            errorMessage = error.localizedDescription
            Haptic.error()
            return false
        }
    }

    func updateTransaction(id: UUID, userId: UUID, amount: Double, currency: Currency,
                           type: TransactionType, categoryId: UUID?,
                           note: String?, date: Date, status: String?, attachmentURL: String?) async {
        let insert = TransactionInsert(
            userId: userId, amount: amount, currency: currency.rawValue,
            type: type.rawValue,
            categoryId: categoryId,
            note: note?.isEmpty == true ? nil : note,
            date: date,
            status: status,
            attachmentURL: attachmentURL)
        do {
            let result: [Transaction] = try await supabase.from("transactions")
                .update(insert)
                .eq("id", value: id.uuidString)
                .select()
                .execute()
                .value
            
            if let updatedTxn = result.first {
                if let idx = transactions.firstIndex(where: { $0.id == id }) {
                    transactions[idx] = updatedTxn
                    print("✅ [Transactions] Updated local state for: \(id)")
                } else {
                    await fetchTransactions(userId: userId)
                }
            } else {
                await fetchTransactions(userId: userId)
            }
            
            Haptic.success()
            updateEcosystem()
        } catch {
            print("❌ [Transactions] UPDATE ERROR: \(error)")
            errorMessage = error.localizedDescription
            Haptic.error()
        }
    }

    func deleteTransaction(id: UUID, userId: UUID) async {
        do {
            try await supabase.from("transactions").delete()
                .eq("id", value: id.uuidString).execute()
            
            // Local update: remove from array
            if let idx = transactions.firstIndex(where: { $0.id == id }) {
                transactions.remove(at: idx)
                print("✅ [Transactions] Deleted and removed from local state: \(id)")
            } else {
                await fetchTransactions(userId: userId)
            }
            
            Haptic.medium()
            updateEcosystem()
        } catch { 
            print("❌ [Transactions] DELETE ERROR: \(error)")
        }
    }

    // MARK: - CRUD: Categories

    func addCategory(userId: UUID, name: String, color: String, icon: String, type: String) async -> Bool {
        let insert = CategoryInsert(userId: userId, familyId: nil, name: name, color: color, icon: icon, type: type)
        print("➕ [Categories] Adding: name=\(name), color=\(color), icon=\(icon), type=\(type), userId=\(userId.uuidString)")
        do {
            try await supabase.from("categories").insert(insert).execute()
            print("✅ [Categories] Added successfully")
            let userType = authVM?.userProfile?.userType ?? "personal"
            await fetchCategories(userId: userId, userType: userType)
            Haptic.success()
            return true
        } catch {
            print("❌ [Categories] ADD ERROR: \(error)")
            errorMessage = error.localizedDescription
            Haptic.error()
            return false
        }
    }

    func deleteCategory(id: UUID, userId: UUID, userType: String) async {
        do {
            try await supabase.from("categories").delete()
                .eq("id", value: id.uuidString).execute()
            await fetchCategories(userId: userId, userType: userType)
            Haptic.medium()
        } catch { print("Delete category error: \(error)") }
    }

    // MARK: - Ecosystem Update
    // Her transaction değişiminde çağrılır.
    // Widget + Watch + LiveActivity + BudgetAlert güncellenir.

    func updateEcosystem() {
        calculateCategorySpending()
        let budgets   = budgetManager?.budgets ?? [:]
        let scheduled = scheduledPaymentVM?.scheduledPayments ?? []
        let recurring = recurringVM?.recurringTransactions ?? []
        SnapshotWriter.write(
            transactions:          transactions,
            categories:            categories,
            budgets:               budgets,
            profile:               authVM?.userProfile,
            primaryCurrency:       primaryCurrency,
            scheduledPayments:     scheduled,
            recurringTransactions: recurring)

        let snap = SnapshotStore.shared.load()
        BudgetAlertEngine.shared.evaluate(budgets: snap.budgetStatuses)
        ZFlowLiveActivityManager.shared.update(snapshot: snap)
        WatchConnector.shared.sendSnapshotToWatch(snap)
    }

    // MARK: - Helpers

    func convert(_ txn: Transaction) -> Double {
        CurrencyConverter.convert(amount: txn.amount, from: txn.currency, to: primaryCurrency)
    }

    func convertToPrimary(amount: Double, from: String) -> Double {
        CurrencyConverter.convert(amount: amount, from: from, to: primaryCurrency)
    }

    func category(for id: UUID?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func categories(for type: TransactionType) -> [Category] {
        categories.filter { cat in
            guard let t = cat.type else { return true }
            return t == type.rawValue || t == "both"
        }
    }

    // MARK: - Private

    private func calculateCategorySpending() {
        let cal = Calendar.current
        let now = Date()
        var newSpending: [UUID: Double] = [:]
        
        // Single O(N) pass to pre-calculate spending for all categories
        for txn in transactions {
            guard let d = txn.date, txn.type == "expense", let catId = txn.categoryId else { continue }
            if cal.isDate(d, equalTo: now, toGranularity: .month) {
                newSpending[catId, default: 0] += convert(txn)
            }
        }
        self.categorySpendingThisMonth = newSpending
    }

    private enum Period { case month, lastMonth, all }

    private func sumConverted(type: String, period: Period = .all) -> Double {
        let cal = Calendar.current
        let now = Date()
        return transactions.filter {
            guard let d = $0.date else { return false }
            guard $0.type == type else { return false }
            switch period {
            case .month:
                return cal.isDate(d, equalTo: now, toGranularity: .month)
            case .lastMonth:
                let lm = cal.date(byAdding: .month, value: -1, to: now) ?? now
                return cal.isDate(d, equalTo: lm, toGranularity: .month)
            case .all:
                return true
            }
        }.reduce(0) { $0 + convert($1) }
    }

    private func seedDefaultCategories(userId: UUID, userType: String) async {
        let inserts = filteredDefaultCategories(for: userType).map {
            CategoryInsert(userId: userId, familyId: nil, name: $0.name, color: $0.color, icon: $0.icon, type: $0.type)
        }
        print("🌱 [Categories] Seeding \(inserts.count) defaults for userType: \(userType)")
        do {
            try await supabase.from("categories").insert(inserts).execute()
            print("🌱 [Categories] Seed INSERT success, now fetching...")
            let fetched: [Category] = try await supabase.from("categories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("name")
                .execute().value
            print("🌱 [Categories] Post-seed fetched \(fetched.count) categories")
            categories = fetched
        } catch {
            print("❌ [Categories] SEED ERROR: \(error)")
        }
    }
}
