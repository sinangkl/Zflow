// ============================================================
// ZFlowWidgets — Main Widget Bundle
// Target: ZFlowWidgets (WidgetKit Extension)
// Xcode: File → New Target → Widget Extension → "ZFlowWidgets"
// ============================================================
import WidgetKit
import SwiftUI

// Lightweight models for Widget to avoid dependency on Models.swift if target membership is missing
private struct WidgetBudget: Codable {
    let category_id: UUID?
    let limit_amount: Double
    let monthly_salary: Double?
    let currency: String?
}

private struct WidgetTransaction: Codable {
    let amount: Double
    let currency: String
    let type: String?
    let category_id: UUID?
}

private struct WidgetRawCategory: Codable {
    let id: UUID
    let name: String
    let color: String
    let icon: String?
    let type: String?
}

// Lightweight converter to avoid dependency issues in Widget Target
private struct WidgetCurrencyConverter {
    private static var ratesToUSD: [String: Double] = [
        "USD": 1.0, "TRY": 36.5, "EUR": 0.92, "GBP": 0.79,
        "CHF": 0.88, "JPY": 152.0, "AED": 3.67, "SAR": 3.75,
        "RUB": 92.0, "CNY": 7.25,
    ]
    static func convert(amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        let fromRate = ratesToUSD[from] ?? 1.0
        let toRate   = ratesToUSD[to]   ?? 1.0
        return (amount / fromRate) * toRate
    }
}

// MARK: - Widget Bundle (tüm widget'ları kayıt eder)

@main
struct ZFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZFlowBalanceWidget()
        ZFlowBudgetWidget()
        ZFlowTransactionsWidget()
        ZFlowLockScreenWidget()
        ZFlowStandbyWidget()
        ZFlowUpcomingWidget()
        QuickAddWidget()
    }
}

// MARK: - Timeline Entry

struct ZFlowEntry: TimelineEntry {
    var date: Date
    var snapshot: ZFlowSnapshot
}

// MARK: - Provider (tüm widget'lar paylaşır)

struct ZFlowProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZFlowEntry {
        ZFlowEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZFlowEntry) -> Void) {
        Task {
            let snap = await fetchLatestSnapshot() ?? SnapshotStore.shared.load()
            completion(ZFlowEntry(date: .now, snapshot: snap))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZFlowEntry>) -> Void) {
        Task {
            let snap = await fetchLatestSnapshot() ?? SnapshotStore.shared.load()
            let entry = ZFlowEntry(date: .now, snapshot: snap)
            
            // Refresh every 15 mins for high freshness
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
    
    // MARK: - Supabase Fetch for Gadgets
    
    private func fetchLatestSnapshot() async -> ZFlowSnapshot? {
        guard let userIdString = AppGroup.defaults.string(forKey: "current_user_id") else { return nil }
        
        let supabaseURL = "https://djembgnyxdjyefjlzsmn.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqZW1iZ255eGRqeWVmamx6c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyNjk2MzgsImV4cCI6MjA4Njg0NTYzOH0.pcCF2853WxOYdc588ifAn_cSLkHOgMd72aJS989hxrE"
        
        let now = Date()
        
        // Helper for REST calls
        func fetch<T: Decodable>(path: String, query: String) async throws -> T {
            var components = URLComponents(string: "\(supabaseURL)/rest/v1/\(path)")!
            components.queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userIdString)")] + query.split(separator: "&").map {
                let parts = $0.split(separator: "=")
                return URLQueryItem(name: String(parts[0]), value: String(parts[1]))
            }
            
            var request = URLRequest(url: components.url!)
            request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        }
        
        do {
            // 1. Fetch Budgets via REST
            let budgets: [WidgetBudget] = try await fetch(path: "budgets", query: "select=*")

            // 2. Fetch Transactions via REST
            let transactions: [WidgetTransaction] = try await fetch(path: "transactions", query: "select=*")

            var snap = SnapshotStore.shared.load()
            let primaryCurrency = snap.currency

            // 3. Always fetch categories for accurate budget matching
            let rawCats: [WidgetRawCategory] = try await fetch(path: "categories", query: "select=*")
            if !rawCats.isEmpty {
                snap.categories = rawCats.map {
                    SnapshotCategory(id: $0.id, name: $0.name, icon: $0.icon ?? "circle",
                                     color: $0.color, type: $0.type ?? "expense")
                }
            }

            // Update Budget Statuses
            var newBudgets: [SnapshotBudget] = []
            let catMap = Dictionary(uniqueKeysWithValues: snap.categories.map { ($0.id, $0) })

            for b in budgets {
                guard let catId = b.category_id, let cat = catMap[catId] else { continue }
                let spent = transactions
                    .filter { $0.type == "expense" && $0.category_id == catId }
                    .reduce(0) { $0 + WidgetCurrencyConverter.convert(amount: $1.amount, from: $1.currency, to: primaryCurrency) }

                newBudgets.append(SnapshotBudget(
                    id: catId,
                    categoryName: cat.name,
                    categoryIcon: cat.icon,
                    categoryColor: cat.color,
                    limit: b.limit_amount,
                    spent: spent,
                    currency: primaryCurrency
                ))
            }

            // Only replace budgetStatuses if Supabase returned data; keep existing otherwise
            if !newBudgets.isEmpty || !budgets.isEmpty {
                snap.budgetStatuses = newBudgets.sorted { $0.ratio > $1.ratio }
            }
            snap.updatedAt = now
            
            // Update totals (only this month's transactions)
            let thisMonthTransactions = transactions
            snap.thisMonthIncome  = thisMonthTransactions.filter { $0.type == "income"  }.reduce(0) { $0 + WidgetCurrencyConverter.convert(amount: $1.amount, from: $1.currency, to: primaryCurrency) }
            snap.thisMonthExpense = thisMonthTransactions.filter { $0.type == "expense" }.reduce(0) { $0 + WidgetCurrencyConverter.convert(amount: $1.amount, from: $1.currency, to: primaryCurrency) }
            
            SnapshotStore.shared.save(snap)
            return snap
            
        } catch {
            print("❌ [Widget] REST fetch update error: \(error)")
            return nil
        }
    }
}

private extension Date {
    var iso8601String: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: self)
    }
}

// MARK: - Placeholder Snapshot

extension ZFlowSnapshot {
    static var placeholder: ZFlowSnapshot {
        ZFlowSnapshot(
            netBalance:       12_840.0,
            thisMonthIncome:  18_500.0,
            thisMonthExpense:  5_660.0,
            currency:         "TRY",
            recentTransactions: [
                SnapshotTransaction(
                    id: UUID(), amount: 450, currency: "TRY",
                    type: "expense", categoryName: "Groceries",
                    categoryIcon: "cart.fill", categoryColor: "#FB923C",
                    note: "Migros", date: .now),
                SnapshotTransaction(
                    id: UUID(), amount: 18500, currency: "TRY",
                    type: "income", categoryName: "Salary",
                    categoryIcon: "banknote.fill", categoryColor: "#34D399",
                    note: nil, date: .now),
            ],
            budgetStatuses: [
                SnapshotBudget(
                    id: UUID(), categoryName: "Groceries",
                    categoryIcon: "cart.fill", categoryColor: "#FB923C",
                    limit: 3000, spent: 2700, currency: "TRY"),
                SnapshotBudget(
                    id: UUID(), categoryName: "Dining Out",
                    categoryIcon: "fork.knife", categoryColor: "#FB7185",
                    limit: 1500, spent: 820, currency: "TRY"),
            ],
            weeklyExpenses: [240, 380, 120, 560, 290, 450, 180],
            updatedAt: .now,
            userDisplayName: "ZFlow",
            userType: "personal")
    }
}
