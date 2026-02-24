import SwiftUI

// MARK: - Root View
// iOS 26 native TabView — Liquid Glass tab bar otomatik
// FAB ZStack overlay ile korunur

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @State private var selectedTab = 0
    @State private var showAddSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(onAddTapped: { showAddSheet = true })
                    .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)

                // Reports + Transactions unified (madde 9)
                TransactionsReportsView()
                    .tabItem { Label("Finance", systemImage: "chart.bar.fill") }.tag(1)

                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }.tag(2)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(3)
            }
            .tint(ZColor.indigo)

            // FAB — tabs üzerinde yüzer, merkezi boşlukta
            ZFlowFAB { showAddSheet = true }
                .padding(.bottom, 80)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showAddSheet) {
            AddTransactionView()
                .environmentObject(transactionVM)
                .environmentObject(authVM)
        }
        .task {
            if let p = authVM.userProfile {
                await transactionVM.refreshData(userId: p.id, userType: p.userType ?? "personal")
            }
        }
        .onChange(of: authVM.userProfile) { _, p in
            if let p { Task { await transactionVM.refreshData(userId: p.id, userType: p.userType ?? "personal") } }
        }
    }
}

// MARK: - FAB

struct ZFlowFAB: View {
    var action: () -> Void
    @Environment(\.colorScheme) var scheme

    var body: some View {
        Button {
            Haptic.medium(); action()
        } label: {
            ZStack {
                Circle()
                    .fill(AppTheme.accentGradient)
                    .frame(width: 54, height: 54)
                    .shadow(color: ZColor.indigo.opacity(scheme == .dark ? 0.6 : 0.38), radius: 14, y: 5)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(FABButtonStyle())
    }
}
