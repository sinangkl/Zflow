import AppIntents
import SwiftUI

/// AppIntent to handle rapid transaction entry from interactive widgets.
public struct QuickAddIntent: AppIntent {
    public static var title: LocalizedStringResource = "Quick Add Transaction"
    public static var description: LocalizedStringResource = "Adds a transaction for a specific category instantly."

    @Parameter(title: "Category")
    var categoryName: String

    @Parameter(title: "Type")
    var type: String // "income" or "expense"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Transaction"
    public var displayRepresentation: DisplayRepresentation { .init(stringLiteral: categoryName) }

    public init() {}
    
    public init(category: String, type: String) {
        self.categoryName = category
        self.type = type
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Load sync store to find the category details (icon, color)
        let snapshot = SnapshotStore.shared.load()
        
        // Prepare the quick add notification
        let quickAdd = WatchQuickAdd(
            amount: 0, // Interactive widget might prompt for amount or use a default/last
            currency: snapshot.currency,
            type: type,
            note: categoryName,
            date: Date()
        )
        
        // Broadcast via NotificationCenter (ZFlowApp listens to this)
        NotificationCenter.default.post(name: .zflowWatchQuickAdd, object: quickAdd)
        
        return .result()
    }
}


