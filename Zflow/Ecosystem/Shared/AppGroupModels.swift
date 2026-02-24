import Foundation

// MARK: - App Group Constants

enum AppGroup {
    static let id              = "group.com.zflow.app"
    static let defaults        = UserDefaults(suiteName: id)!

    enum Key {
        static let snapshot    = "zflow.snapshot.v2"
        static let budgetAlert = "zflow.budgetAlerts.v2"
        static let liveState   = "zflow.liveState.v1"
    }
}

// MARK: - Shared Snapshot

struct ZFlowSnapshot: Codable {
    var netBalance: Double
    var thisMonthIncome: Double
    var thisMonthExpense: Double
    var currency: String
    var recentTransactions: [SnapshotTransaction]
    var budgetStatuses: [SnapshotBudget]
    var weeklyExpenses: [Double]
    var updatedAt: Date
    var userDisplayName: String
    var userType: String

    static var empty: ZFlowSnapshot {
        ZFlowSnapshot(
            netBalance: 0, thisMonthIncome: 0, thisMonthExpense: 0,
            currency: "TRY", recentTransactions: [], budgetStatuses: [],
            weeklyExpenses: Array(repeating: 0, count: 7),
            updatedAt: Date(), userDisplayName: "ZFlow", userType: "personal")
    }


}

struct SnapshotTransaction: Codable, Identifiable {
    var id: UUID
    var amount: Double
    var currency: String
    var type: String
    var categoryName: String
    var categoryIcon: String
    var categoryColor: String
    var note: String?
    var date: Date
}

struct SnapshotBudget: Codable, Identifiable {
    var id: UUID
    var categoryName: String
    var categoryIcon: String
    var categoryColor: String
    var limit: Double
    var spent: Double
    var currency: String

    var ratio: Double      { limit > 0 ? spent / limit : 0 }
    var percentage: Int    { Int(min(ratio * 100, 100)) }
    var isWarning: Bool    { ratio >= 0.80 && ratio < 1.0 }
    var isExceeded: Bool   { ratio >= 1.0 }
    var isCritical: Bool   { ratio >= 0.95 }

    var statusColor: ZFlowBudgetColor {
        if isExceeded { return .exceeded }
        if isCritical { return .critical }
        if isWarning  { return .warning  }
        return .safe
    }
}

enum ZFlowBudgetColor: String, Codable {
    case safe, warning, critical, exceeded

    var hex: String {
        switch self {
        case .safe:     return "#30D158"
        case .warning:  return "#FF9F0A"
        case .critical: return "#FF6961"
        case .exceeded: return "#FF453A"
        }
    }
}

// MARK: - Snapshot Store

final class SnapshotStore {
    static let shared = SnapshotStore()
    private init() {}

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func save(_ snapshot: ZFlowSnapshot) {
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: AppGroup.Key.snapshot)
        AppGroup.defaults.synchronize()
    }

    func load() -> ZFlowSnapshot {
        decoder.dateDecodingStrategy = .iso8601
        guard let data = AppGroup.defaults.data(forKey: AppGroup.Key.snapshot),
              let snap = try? decoder.decode(ZFlowSnapshot.self, from: data) else {
            return .empty
        }
        return snap
    }
}

// MARK: - Budget Alert Model

struct BudgetAlertPayload: Codable, Identifiable {
    var id: UUID = UUID()
    var categoryId: UUID
    var categoryName: String
    var categoryIcon: String
    var categoryColor: String
    var spent: Double
    var limit: Double
    var currency: String
    var alertType: AlertType
    var timestamp: Date

    enum AlertType: String, Codable {
        case warning  = "warning"
        case critical = "critical"
        case exceeded = "exceeded"
    }

    var title: String {
        switch alertType {
        case .warning:  return "Budget Warning"
        case .critical: return "Almost at Limit!"
        case .exceeded: return "Budget Exceeded!"
        }
    }

    var body: String {
        let pct = limit > 0 ? Int((spent / limit) * 100) : 0
        switch alertType {
        case .warning:
            return "\(categoryName): \(pct)% of budget used."
        case .critical:
            return "\(categoryName): Only \((limit - spent).formattedShort()) left!"
        case .exceeded:
            return "\(categoryName): Over by \((spent - limit).formattedShort()) \(currency)."
        }
    }
}

// MARK: - Number Formatting

extension Double {
    func formattedShort() -> String {
        if abs(self) >= 1_000_000 { return String(format: "%.1fM", self / 1_000_000) }
        if abs(self) >= 1_000     { return String(format: "%.1fK", self / 1_000) }
        return String(format: "%.0f", self)
    }

    func formattedCurrencySimple(code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = ["JPY", "KRW"].contains(code) ? 0 : 2
        f.minimumFractionDigits = f.maximumFractionDigits
        return f.string(from: NSNumber(value: self)) ?? "\(code) \(self)"
    }
}
