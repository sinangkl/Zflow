import Foundation

// MARK: - App Group Constants

public enum AppGroup {
    public static let id              = "group.com.zflow.app"
    public static let defaults        = UserDefaults(suiteName: id)!

    public enum Key {
        public static let snapshot    = "zflow.snapshot.v2"
        public static let budgetAlert = "zflow.budgetAlerts.v2"
        public static let liveState   = "zflow.liveState.v1"
        public static let language    = "zflow.language.v2"
    }
}

// MARK: - Shared Snapshot

public struct ZFlowSnapshot: Codable {
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
    var categories: [SnapshotCategory]
    var categoryBreakdown: [SnapshotCategoryBreakdown]
    var scheduledPayments: [SnapshotScheduledPayment]
    var recurringTransactions: [SnapshotRecurringTransaction]
    var accentPrimaryHex: String?
    var accentSecondaryHex: String?

    public static var empty: ZFlowSnapshot {
        ZFlowSnapshot(
            netBalance: 0, thisMonthIncome: 0, thisMonthExpense: 0,
            currency: "TRY", recentTransactions: [], budgetStatuses: [],
            weeklyExpenses: Array(repeating: 0, count: 7),
            updatedAt: Date(), userDisplayName: "ZFlow", userType: "personal",
            categories: [], categoryBreakdown: [], scheduledPayments: [],
            recurringTransactions: [],
            accentPrimaryHex: "#5E5CE6", accentSecondaryHex: "#7C3AED")
    }

    // Backwards-compatible decoding for snapshots without the new fields
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        netBalance = try c.decode(Double.self, forKey: .netBalance)
        thisMonthIncome = try c.decode(Double.self, forKey: .thisMonthIncome)
        thisMonthExpense = try c.decode(Double.self, forKey: .thisMonthExpense)
        currency = try c.decode(String.self, forKey: .currency)
        recentTransactions = try c.decode([SnapshotTransaction].self, forKey: .recentTransactions)
        budgetStatuses = try c.decode([SnapshotBudget].self, forKey: .budgetStatuses)
        weeklyExpenses = try c.decode([Double].self, forKey: .weeklyExpenses)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        userDisplayName = try c.decode(String.self, forKey: .userDisplayName)
        userType = try c.decode(String.self, forKey: .userType)
        categories = (try? c.decode([SnapshotCategory].self, forKey: .categories)) ?? []
        categoryBreakdown = (try? c.decode([SnapshotCategoryBreakdown].self, forKey: .categoryBreakdown)) ?? []
        scheduledPayments = (try? c.decode([SnapshotScheduledPayment].self, forKey: .scheduledPayments)) ?? []
        recurringTransactions = (try? c.decode([SnapshotRecurringTransaction].self, forKey: .recurringTransactions)) ?? []
        accentPrimaryHex = try? c.decode(String.self, forKey: .accentPrimaryHex)
        accentSecondaryHex = try? c.decode(String.self, forKey: .accentSecondaryHex)
    }

    public init(netBalance: Double, thisMonthIncome: Double, thisMonthExpense: Double,
         currency: String, recentTransactions: [SnapshotTransaction],
         budgetStatuses: [SnapshotBudget], weeklyExpenses: [Double],
         updatedAt: Date, userDisplayName: String, userType: String,
         categories: [SnapshotCategory] = [], categoryBreakdown: [SnapshotCategoryBreakdown] = [], scheduledPayments: [SnapshotScheduledPayment] = [],
         recurringTransactions: [SnapshotRecurringTransaction] = [],
         accentPrimaryHex: String? = nil, accentSecondaryHex: String? = nil) {
        self.netBalance = netBalance
        self.thisMonthIncome = thisMonthIncome
        self.thisMonthExpense = thisMonthExpense
        self.currency = currency
        self.recentTransactions = recentTransactions
        self.budgetStatuses = budgetStatuses
        self.weeklyExpenses = weeklyExpenses
        self.updatedAt = updatedAt
        self.userDisplayName = userDisplayName
        self.userType = userType
        self.categories = categories
        self.categoryBreakdown = categoryBreakdown
        self.scheduledPayments = scheduledPayments
        self.recurringTransactions = recurringTransactions
        self.accentPrimaryHex = accentPrimaryHex
        self.accentSecondaryHex = accentSecondaryHex
    }
}

// MARK: - Snapshot Category (for Watch category picker)

public struct SnapshotCategory: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var color: String
    public var type: String  // "income" | "expense" | "both"
}

// MARK: - Category Breakdown (for Watch reports)

public struct SnapshotCategoryBreakdown: Codable, Identifiable {
    public var id: UUID       // category id
    public var name: String
    public var icon: String
    public var color: String
    public var total: Double
    public var percent: Double
}

public struct SnapshotTransaction: Codable, Identifiable {
    public var id: UUID
    public var amount: Double
    public var currency: String
    public var type: String
    public var categoryName: String
    public var categoryIcon: String
    public var categoryColor: String
    public var note: String?
    public var date: Date
}

public struct SnapshotScheduledPayment: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var amount: Double
    public var currency: String
    public var type: String
    public var scheduledDate: Date
    public var status: String
}

public struct SnapshotRecurringTransaction: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var expectedAmount: Double?
    public var currency: String
    public var transactionType: String  // "income" | "expense"
    public var dayOfMonth: Int
    public var categoryName: String
    public var categoryIcon: String
    public var categoryColor: String
    public var isActive: Bool
}

public struct SnapshotBudget: Codable, Identifiable {
    public var id: UUID
    public var categoryName: String
    public var categoryIcon: String
    public var categoryColor: String
    public var limit: Double
    public var spent: Double
    public var currency: String

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
// Shared across main app, Widget, and Watch targets.

extension Double {
    /// Short numeric format, optional currency code appended.
    /// e.g. 12500.formattedShort() → "12.5K"
    ///      12500.formattedShort(code: "TRY") → "12.5K TRY"
    public func formattedShort(code: String = "") -> String {
        let suffix = code.isEmpty ? "" : " \(code)"
        if abs(self) >= 1_000_000 { return String(format: "%.1fM\(suffix)", self / 1_000_000) }
        if abs(self) >= 1_000     { return String(format: "%.1fK\(suffix)", self / 1_000) }
        return String(format: "%.0f\(suffix)", self)
    }

    public func formattedCurrencySimple(code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = ["JPY", "KRW"].contains(code) ? 0 : 2
        f.minimumFractionDigits = f.maximumFractionDigits
        return f.string(from: NSNumber(value: self)) ?? "\(code) \(self)"
    }
}

