import SwiftUI
import Combine

@main
struct ZFlowApp: App {
    @StateObject private var authVM        = AuthViewModel()
    @StateObject private var transactionVM = TransactionViewModel()
    @StateObject private var budgetManager = BudgetManager()

    // Ecosystem
    @StateObject private var watchConnector = WatchConnector.shared

    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @ObservedObject private var languageManager = LanguageManager.shared

    init() {
        // Bildirim kategorilerini kayıt et
        BudgetAlertEngine.registerCategories()
        // Bildirim izni iste
        Task { await BudgetAlertEngine.requestPermission() }
        // Live Activity başlat
        ZFlowLiveActivityManager.shared.start(snapshot: SnapshotStore.shared.load())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(transactionVM)
                .environmentObject(budgetManager)
                .preferredColorScheme(colorSchemeValue)
                .id(languageManager.currentLanguage) // Force full rebuild on language change
                .tint(ZColor.indigo)
                // Watch'tan gelen Quick-Add işlemini dinle
                .onReceive(
                    NotificationCenter.default.publisher(for: .zflowWatchQuickAdd)
                ) { note in
                    guard let item = note.object as? WatchQuickAdd,
                          let uid  = authVM.currentUserId else { return }
                    let catId = transactionVM.categories
                        .first { $0.name.lowercased() == (item.note ?? "").lowercased() }?.id
                    Task {
                        await transactionVM.addTransaction(
                            userId:     uid,
                            amount:     item.amount,
                            currency:   Currency(rawValue: item.currency) ?? .try_,
                            type:       item.type == "income" ? .income : .expense,
                            categoryId: catId,
                            note:       item.note,
                            date:       item.date)
                    }
                }
                // Deep link yönlendirici
                .onOpenURL { url in handleDeepLink(url) }
        }
    }

    // MARK: - Deep Link

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "zflow" else { return }
        switch url.host {
        case "budgets":      UserDefaults.standard.set(3, forKey: "selectedTab")
        case "transactions": UserDefaults.standard.set(1, forKey: "selectedTab")
        case "home":         UserDefaults.standard.set(0, forKey: "selectedTab")
        default: break
        }
    }

    // MARK: - Color Scheme

    private var colorSchemeValue: ColorScheme? {
        switch appColorScheme {
        case "light": .light
        case "dark":  .dark
        default:       nil
        }
    }
}
