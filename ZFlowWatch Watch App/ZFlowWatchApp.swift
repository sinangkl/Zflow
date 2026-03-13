// ============================================================
// ZFlow Watch App — Entry Point
// Target: ZFlowWatch (watchOS Extension)
// watchOS 9+
// ============================================================
import SwiftUI
import WatchKit

@main
struct ZFlowWatchApp: App {
    @StateObject private var store = WatchStore.shared
    @StateObject private var securityMgr = ZFlowSecurityManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .overlay {
                    if securityMgr.isLockEnabled && !securityMgr.isAuthenticated {
                        WatchLockScreen()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        securityMgr.lock()
                    } else if newPhase == .active {
                        securityMgr.authenticate { _ in }
                    }
                }
        }
    }
}

// MARK: - Watch Root Navigation

struct WatchRootView: View {
    @EnvironmentObject var store: WatchStore
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Dynamic gradient background for watch
            ZStack {
                store.accentPrimary.opacity(0.15)
                
                LinearGradient(
                    colors: [
                        store.accentPrimary.opacity(0.35),
                        store.accentSecondary.opacity(0.2),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                NavigationStack {
                    WatchDashboardView()
                }
                .tag(0)

                NavigationStack {
                    WatchReportsView()
                }
                .tag(1)

                NavigationStack {
                    WatchCurrencyView()
                }
                .tag(2)

                NavigationStack {
                    WatchSettingsView()
                }
                .tag(3)
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
