import SwiftUI
import Combine
import BackgroundTasks
import AppTrackingTransparency
import WidgetKit
import Supabase
import GoogleSignIn

@main
struct ZFlowApp: App {
    @UIApplicationDelegateAdaptor(ZFlowAppDelegate.self) var appDelegate

    @StateObject private var authVM             = AuthViewModel()
    @StateObject private var transactionVM      = TransactionViewModel()
    @StateObject private var budgetManager      = BudgetManager()
    @StateObject private var scheduledPaymentVM = ScheduledPaymentViewModel()
    @StateObject private var recurringVM       = RecurringTransactionViewModel()
    @StateObject private var securityMgr        = ZFlowSecurityManager.shared
    @StateObject private var walletPassManager  = WalletPassManager()
    @StateObject private var familyVM           = FamilyViewModel()
    @StateObject private var activityVM         = FamilyActivityViewModel()
    @StateObject private var goalVM             = GoalViewModel()
    @StateObject private var pushManager        = PushNotificationManager.shared
    @StateObject private var calMgr             = CalendarManager.shared
    @Environment(\.scenePhase) private var scenePhase

    // Ecosystem
    @StateObject private var watchConnector = WatchConnector.shared

    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @AppStorage("profileCardColor") private var appThemeColorHex: String = "#5E5CE6"
    @ObservedObject private var languageManager = LanguageManager.shared

    init() {
        // Google Sign-In — uygulama başlarken bir kez yapılandır
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "541490785310-loi70nv5nkhfgqkq3dfqie9jt8qma3ii.apps.googleusercontent.com"
        )
        // NSLocalizedString'in uygulama diline göre çalışmasını sağla
        Localizer.setupBundleOverride()
        // Bildirim kategorilerini kayıt et
        BudgetAlertEngine.registerCategories()
        // Bildirim izni iste
        Task {
            _ = await BudgetAlertEngine.requestPermission()
            // APNs push registration
            await PushNotificationManager.shared.requestPermissionAndRegister()
        }
        // Live Activity başlat
        ZFlowLiveActivityManager.shared.start(snapshot: SnapshotStore.shared.load())
        // Background refresh görevi kayıt (applicationDidFinishLaunching'den önce olmalı)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.zflow.bgrefresh", using: nil) { task in
            WidgetCenter.shared.reloadAllTimelines()
            (task as? BGAppRefreshTask)?.setTaskCompleted(success: true)
            ZFlowApp.scheduleBGRefresh()
        }
    }

    // MARK: - Background Refresh

    static func scheduleBGRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.zflow.bgrefresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(transactionVM)
                .environmentObject(budgetManager)
                .environmentObject(recurringVM)
                .environmentObject(scheduledPaymentVM)
                .environmentObject(walletPassManager)
                .environmentObject(familyVM)
                .environmentObject(activityVM)
                .environmentObject(goalVM)
                .environmentObject(pushManager)
                .environmentObject(calMgr)
                .preferredColorScheme(colorSchemeValue)
                .id(languageManager.currentLanguage)
                .tint(Color(hex: appThemeColorHex))
                .onAppear {
                    // Link dependencies
                    transactionVM.authVM             = authVM
                    transactionVM.budgetManager      = budgetManager
                    transactionVM.scheduledPaymentVM = scheduledPaymentVM
                    transactionVM.recurringVM        = recurringVM
                    transactionVM.calMgr             = calMgr
                    // İlk BG refresh planla
                    ZFlowApp.scheduleBGRefresh()
                    // ATT izni iste (ilk açılışta)
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                            await ATTrackingManager.requestTrackingAuthorization()
                        }
                    }
                }
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
                // Deep link yönlendirici (Google Sign In önce handle eder)
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    handleDeepLink(url)
                }
                .overlay {
                    if securityMgr.isLockEnabled && !securityMgr.isAuthenticated {
                        ZFlowLockScreen()
                    }
                }
                .sheet(isPresented: $authVM.showResetPasswordSheet) {
                    ChangePasswordView().environmentObject(authVM)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        securityMgr.lock()
                        transactionVM.stopRealtime()
                        budgetManager.stopRealtime()
                        ZFlowApp.scheduleBGRefresh()
                    } else if newPhase == .active {
                        securityMgr.authenticate { _ in }
                        reconnectRealtime()
                        // Fetch scheduled payments when app becomes active
                        if let uid = authVM.currentUserId {
                            Task {
                                await scheduledPaymentVM.fetchScheduledPayments(userId: uid)
                            }
                        }
                    }
                }
        }
    }

    // MARK: - Realtime Reconnection

    private func reconnectRealtime() {
        guard let uid = authVM.currentUserId, let profile = authVM.userProfile else { return }
        
        // Always ensure sockets are subscribed when app becomes active
        transactionVM.subscribeToRealtime(userId: uid)
        budgetManager.subscribeToRealtime(userId: uid)

        let key = "zflow.lastRealtimeRefresh"
        let lastRefresh = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: key))
        
        // Only trigger a heavy full HTTP data fetch if > 30 seconds passed
        guard Date().timeIntervalSince(lastRefresh) > 30 else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
        
        Task {
            await transactionVM.refreshData(userId: uid, userType: profile.userType ?? "personal")
            await budgetManager.fetchBudgets(userId: uid)
        }
    }

    // MARK: - Deep Link

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "zflow" else { return }
        switch url.host {
        case "budgets":         UserDefaults.standard.set(3, forKey: "selectedTab")
        case "transactions":    UserDefaults.standard.set(1, forKey: "selectedTab")
        case "home":            UserDefaults.standard.set(0, forKey: "selectedTab")
        case "addTransaction":  NotificationCenter.default.post(name: .zflowOpenAddSheet, object: nil)
        case "reset-password":
            // URL içindeki token'ı Supabase'e teslim edip geçici oturum kuruyoruz,
            // ardından şifre sıfırlama ekranını açıyoruz.
            Task {
                do {
                    try await SupabaseManager.shared.client.auth.session(from: url)
                    authVM.showResetPasswordSheet = true
                } catch {
                    print("❌ [DeepLink] Reset-password session hatası: \(error.localizedDescription)")
                    authVM.errorMessage = NSLocalizedString("auth.resetLinkExpired", comment: "")
                }
            }
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
