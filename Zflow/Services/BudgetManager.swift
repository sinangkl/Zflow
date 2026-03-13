import Foundation
import SwiftUI
import Combine
import WidgetKit
import Supabase
import PostgREST
import Realtime

@MainActor
final class BudgetManager: ObservableObject {
    static let budgetsDidChange = Notification.Name("BudgetManagerBudgetsDidChange")

    @Published var budgets: [UUID: Double] = [:]       // categoryId -> limit
    @Published var monthlySalary: Double = 0
    @Published var isLoading = false

    private let key = "zflow_categoryBudgets_v2"
    private let salaryKey = "zflow_monthlySalary_v2"
    private let supabase = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var cancellables: Set<AnyCancellable> = []

    init() { 
        loadLocal()
        
        NotificationCenter.default
            .publisher(for: Notification.Name("ZFlowDidLogout"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.clearAll() }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    func fetchBudgets(userId: UUID, familyId: UUID? = nil) async {
        isLoading = true
        do {
            // Fetch personal budgets
            let remoteBudgets: [Budget] = try await supabase.from("budgets")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            // Fetch family budgets if in a family
            var familyBudgets: [Budget] = []
            if let fid = familyId {
                familyBudgets = try await supabase.from("budgets")
                    .select()
                    .eq("family_id", value: fid.uuidString)
                    .execute()
                    .value
            }
            
            var newBudgets: [UUID: Double] = [:]
            var newSalary: Double = 0
            
            let allBudgets = remoteBudgets + familyBudgets
            for b in allBudgets {
                if let catId = b.categoryId {
                    newBudgets[catId] = b.limitAmount
                }
                if let salary = b.monthlySalary, salary > 0 {
                    newSalary = salary
                }
            }
            
            self.budgets = newBudgets
            self.monthlySalary = newSalary
            saveLocal()
            print("✅ [Budgets] Fetched \(allBudgets.count) budgets (Personal + Family)")
            subscribeToRealtime(userId: userId, familyId: familyId)
        } catch {
            print("❌ [Budgets] FETCH ERROR: \(error)")
        }
        isLoading = false
    }

    func stopRealtime() {
        let channel = realtimeChannel
        realtimeChannel = nil
        Task {
            await channel?.unsubscribe()
        }
    }

    func subscribeToRealtime(userId: UUID, familyId: UUID? = nil) {
        guard realtimeChannel == nil else { return }
        
        let channel = supabase.realtimeV2
            .channel("public:budgets:mixed")
        
        realtimeChannel = channel
        
        // Listen to personal changes
        _ = channel.onPostgresChange(
            AnyAction.self,
            table: "budgets",
            filter: "user_id=eq.\(userId.uuidString)"
        ) { action in
            Task { @MainActor [weak self] in self?.handleRealtimeChange(action) }
        }

        // Listen to family changes
        if let fid = familyId {
            _ = channel.onPostgresChange(
                AnyAction.self,
                table: "budgets",
                filter: "family_id=eq.\(fid.uuidString)"
            ) { action in
                Task { @MainActor [weak self] in self?.handleRealtimeChange(action) }
            }
        }
        
        Task {
            do {
                try await channel.subscribeWithError()
                print("✅ [Realtime] Budget channel subscribed")
            } catch {
                print("❌ [Realtime] Budget subscribe error: \(error)")
            }
        }
    }

    private func applyBudget(_ b: Budget) {
        if let catId = b.categoryId {
            budgets[catId] = b.limitAmount
        } else if let salary = b.monthlySalary, salary > 0 {
            monthlySalary = salary
        }
    }

    private func handleRealtimeChange(_ action: AnyAction) {
        print("🔔 [Realtime] Budget change detected")

        let decoder = PostgrestClient.Configuration.jsonDecoder
        switch action {
        case .insert(let a):
            if let b: Budget = try? a.decodeRecord(decoder: decoder) {
                applyBudget(b); saveLocal(); notifyChange()
            }
        case .update(let a):
            if let b: Budget = try? a.decodeRecord(decoder: decoder) {
                applyBudget(b); saveLocal(); notifyChange()
            }
        case .delete(let a):
            if let old: Budget = try? a.decodeOldRecord(decoder: decoder) {
                if let catId = old.categoryId { budgets.removeValue(forKey: catId) }
                saveLocal(); notifyChange()
            }
        }
    }

    func setBudget(userId: UUID, categoryId: UUID, limit: Double, currency: String = "TRY") {
        // Optimistic update
        budgets[categoryId] = limit
        saveLocal()
        notifyChange()

        // Sync to Supabase: delete existing record then insert fresh
        Task {
            do {
                // Delete existing record for this (user, category) pair if any
                try await supabase.from("budgets")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("category_id", value: categoryId.uuidString)
                    .execute()

                let insert = BudgetInsert(
                    userId: userId,
                    familyId: nil,
                    categoryId: categoryId,
                    limitAmount: limit,
                    monthlySalary: monthlySalary > 0 ? monthlySalary : nil,
                    budgetType: "monthly",
                    currency: currency
                )

                try await supabase.from("budgets")
                    .insert(insert)
                    .execute()

                print("✅ [Budgets] Saved budget for category: \(categoryId)")
            } catch {
                print("❌ [Budgets] SAVE ERROR: \(error)")
            }
        }
    }

    func setMonthlySalary(userId: UUID, salary: Double, currency: String = "TRY") {
        monthlySalary = salary
        saveLocal()
        notifyChange()
        
        Task {
            do {
                let insert = BudgetInsert(
                    userId: userId,
                    familyId: nil,
                    categoryId: nil, // Global salary record
                    limitAmount: 0,
                    monthlySalary: salary,
                    budgetType: "monthly",
                    currency: currency
                )
                
                try await supabase.from("budgets")
                    .upsert(insert, onConflict: "user_id,category_id")
                    .execute()
                
                print("✅ [Budgets] Updated monthly salary: \(salary)")
            } catch {
                print("❌ [Budgets] SALARY UPDATE ERROR: \(error)")
            }
        }
    }

    func removeBudget(userId: UUID, categoryId: UUID) {
        // Optimistic update
        budgets.removeValue(forKey: categoryId)
        saveLocal()
        notifyChange()
        
        // Sync to Supabase
        Task {
            do {
                try await supabase.from("budgets")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("category_id", value: categoryId.uuidString)
                    .execute()
                
                print("✅ [Budgets] Deleted budget for category: \(categoryId)")
            } catch {
                print("❌ [Budgets] DELETE ERROR: \(error)")
            }
        }
    }

    func setFamilyBudget(familyId: UUID, categoryId: UUID, limit: Double, currency: String = "TRY") {
        budgets[categoryId] = limit
        saveLocal()
        notifyChange()

        Task {
            do {
                // Delete existing family budget for this category
                try await supabase.from("budgets")
                    .delete()
                    .eq("family_id", value: familyId.uuidString)
                    .eq("category_id", value: categoryId.uuidString)
                    .execute()

                let insert = BudgetInsert(
                    userId: nil,
                    familyId: familyId,
                    categoryId: categoryId,
                    limitAmount: limit,
                    monthlySalary: nil,
                    budgetType: "monthly",
                    currency: currency
                )

                try await supabase.from("budgets")
                    .insert(insert)
                    .execute()
            } catch {
                print("❌ [FamilyBudgets] SAVE ERROR: \(error)")
            }
        }
    }

    func budget(for categoryId: UUID) -> Double? { budgets[categoryId] }

    func spendingRatio(categoryId: UUID, spent: Double) -> Double? {
        guard let limit = budgets[categoryId], limit > 0 else { return nil }
        return spent / limit
    }

    func statusColor(ratio: Double) -> Color {
        if ratio >= 1.0 { return .red }
        if ratio >= 0.8 { return .orange }
        if ratio >= 0.5 { return .yellow }
        return .green
    }

    // MARK: - Persistence (UserDefaults)

    private func saveLocal() {
        let dict = budgets.reduce(into: [String: Double]()) { $0[$1.key.uuidString] = $1.value }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
        UserDefaults.standard.set(monthlySalary, forKey: salaryKey)
    }

    func loadLocal() {
        monthlySalary = UserDefaults.standard.double(forKey: salaryKey)
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        budgets = dict.reduce(into: [UUID: Double]()) {
            if let uuid = UUID(uuidString: $1.key) { $0[uuid] = $1.value }
        }
    }

    func clearAll() {
        budgets.removeAll()
        saveLocal()
        notifyChange()
    }

    private func notifyChange() {
        WidgetCenter.shared.reloadTimelines(ofKind: "ZFlowBudgetWidget")
        NotificationCenter.default.post(name: BudgetManager.budgetsDidChange, object: nil)
    }
}
