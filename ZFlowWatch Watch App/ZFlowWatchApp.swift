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

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
        }
    }
}

// MARK: - Watch Root Navigation

struct WatchRootView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        NavigationStack {
            WatchDashboardView()
        }
    }
}
