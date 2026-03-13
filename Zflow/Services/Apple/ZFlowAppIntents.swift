// ============================================================
// ZFlow — Siri & Shortcuts AppIntents
// Target: Zflow (main app)
// iOS 16+ — AppIntents + AppShortcuts
// ============================================================

import AppIntents
import SwiftUI

// MARK: - 1. Add Transaction Intent

struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "ZFlow'a İşlem Ekle"
    static var description = IntentDescription("Hızlıca bir gelir veya gider ekleyin.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Tutar")
    var amount: Double

    @Parameter(title: "Kategori")
    var categoryName: String

    @Parameter(title: "Tür", default: "Gider")
    var type: String  // "Gelir" or "Gider"

    @Parameter(title: "Not")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("ZFlow'a \(\.$amount) ekle") {
            \.$categoryName
            \.$type
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Persist the pending transaction to App Group so the main app can pick it up
        let payload: [String: Any] = [
            "amount": amount,
            "category": categoryName,
            "type": type == "Gelir" ? "income" : "expense",
            "note": note ?? ""
        ]
        AppGroup.defaults.set(payload, forKey: "pendingSiriTransaction")
        AppGroup.defaults.synchronize()
        return .result(value: "\(amount) TL \(categoryName) başarıyla kaydedildi!")
    }
}

// MARK: - 2. Check Balance Intent

struct CheckBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "ZFlow Bakiyemi Göster"
    static var description = IntentDescription("Mevcut net bakiyeni öğren.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Read from App Group / SnapshotStore
        let snap = SnapshotStore.shared.load()
        let balance = String(format: "%.2f", snap.netBalance)
        return .result(value: "ZFlow bakiyen: \(balance) \(snap.currency)")
    }
}

// MARK: - 3. Budget Status Intent

struct BudgetStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "ZFlow Bütçe Durumu"
    static var description = IntentDescription("Tüm aktif bütçelerinin durumunu öğren.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let snap       = SnapshotStore.shared.load()
        let budgets    = snap.budgetStatuses
        if budgets.isEmpty {
            return .result(value: "Aktif bütçen bulunmuyor.")
        }
        let summary = budgets.map { "\($0.categoryName): %\($0.percentage)" }.joined(separator: ", ")
        return .result(value: "ZFlow bütçe durumu: \(summary)")
    }
}

// MARK: - App Shortcuts Provider

public struct ZFlowAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "ZFlow'a \(.applicationName) ekle",
                "\(.applicationName)'a harcama ekle",
                "\(.applicationName)'a gelir ekle"
            ],
            shortTitle: "İşlem Ekle",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: QuickAddIntent(),
            phrases: [
                "Add Transaction to \(.applicationName)",
                "Record Transaction in \(.applicationName)",
                "I spent money in \(.applicationName)",
                "New transaction in \(.applicationName)"
            ],
            shortTitle: "Add Transaction",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "\(.applicationName) bakiyemi göster",
                "\(.applicationName) hesabım ne kadar"
            ],
            shortTitle: "Bakiyemi Göster",
            systemImageName: "creditcard.fill"
        )
        AppShortcut(
            intent: BudgetStatusIntent(),
            phrases: [
                "\(.applicationName) bütçe durumum",
                "\(.applicationName) bütçelerim nasıl"
            ],
            shortTitle: "Bütçe Durumu",
            systemImageName: "chart.pie.fill"
        )
    }
}

/// Dynamic options provider for Categories in Siri/Shortcuts
public struct CategoryOptionsProvider: DynamicOptionsProvider {
    public func results() async throws -> [String] {
        let snapshot = SnapshotStore.shared.load()
        return snapshot.budgetStatuses.map { $0.categoryName }
    }
}
