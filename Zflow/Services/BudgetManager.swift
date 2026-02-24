import Foundation
import SwiftUI
import Combine

@MainActor
final class BudgetManager: ObservableObject {
    @Published var budgets: [UUID: Double] = [:]       // categoryId -> limit
    @Published var isLoading = false

    private let key = "zflow_categoryBudgets_v2"
    private let supabase = SupabaseManager.shared.client

    init() { loadLocal() }

    // MARK: - Public API

    func setBudget(for categoryId: UUID, limit: Double) {
        budgets[categoryId] = limit
        saveLocal()
    }

    func removeBudget(for categoryId: UUID) {
        budgets.removeValue(forKey: categoryId)
        saveLocal()
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
    }

    func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        budgets = dict.reduce(into: [UUID: Double]()) {
            if let uuid = UUID(uuidString: $1.key) { $0[uuid] = $1.value }
        }
    }

    func clearAll() {
        budgets.removeAll()
        saveLocal()
    }
}
