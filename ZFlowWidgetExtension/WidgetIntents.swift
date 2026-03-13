import AppIntents
import WidgetKit

// MARK: - Complete Scheduled Payment (Interactive iOS 17 Widget Button)

/// Marks a scheduled payment as complete directly from the home screen widget.
/// The action writes to the shared App Group store; the main app picks it up on next foreground.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct CompletePaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "Ödemeyi Onayla"
    static var description = IntentDescription("Zamanlanmış ödemeyi doğrudan widget'tan onayla.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Ödeme ID")
    var paymentId: String

    @Parameter(title: "Ödeme Adı")
    var paymentName: String

    init() {}
    init(paymentId: String, paymentName: String) {
        self.paymentId = paymentId
        self.paymentName = paymentName
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        var pending = AppGroup.defaults.array(forKey: "pendingWidgetPayments") as? [String] ?? []
        pending.append(paymentId)
        AppGroup.defaults.set(pending, forKey: "pendingWidgetPayments")
        AppGroup.defaults.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpcomingPaymentsWidget")
        print("✅ [Widget] Marked payment '\(paymentName)' as done from widget.")
        return .result(value: true)
    }
}

// MARK: - Quick Add Transaction (Interactive)

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct QuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Transaction"
    static var description = IntentDescription("Adds a quick transaction to a category.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Category Name")
    var categoryName: String

    init() {}
    init(category: String) {
        self.categoryName = category
    }

    func perform() async throws -> some IntentResult {
        let payload: [String: Any] = ["category": categoryName, "source": "widget"]
        AppGroup.defaults.set(payload, forKey: "pendingQuickAdd")
        AppGroup.defaults.synchronize()
        return .result()
    }
}
