import SwiftUI

// MARK: - Root View
// HIG: Tab bar native SwiftUI, FAB below tab bar safe area
// Tab bar hides on scroll down, shows on scroll up (Apple HIG scroll behavior)

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @StateObject private var scheduledPaymentVM = ScheduledPaymentViewModel()
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var isTabBarHidden = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(onAddTapped: { showAddSheet = true }, onScrollChanged: { isDown in
                    withAnimation(.easeInOut(duration: 0.25)) { isTabBarHidden = isDown }
                })
                    .tabItem { Label(NSLocalizedString("tab.home", comment: ""), systemImage: "house.fill") }.tag(0)

                TransactionsReportsView()
                    .tabItem { Label(NSLocalizedString("tab.transactions", comment: ""), systemImage: "chart.bar.fill") }.tag(1)

                CalendarView()
                    .environmentObject(scheduledPaymentVM)
                    .tabItem { Label(NSLocalizedString("tab.calendar", comment: ""), systemImage: "calendar") }.tag(2)

                SettingsView()
                    .tabItem { Label(NSLocalizedString("tab.settings", comment: ""), systemImage: "gearshape.fill") }.tag(3)
            }
            .tint(ZColor.indigo)
            .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)

            // FAB — always visible, above tab bar
            ZFlowFAB { showAddSheet = true }
                .padding(.trailing, 20)
                .padding(.bottom, isTabBarHidden ? 24 : 62) // Above tab bar or near bottom
                .frame(maxWidth: .infinity, alignment: .trailing)
                .animation(.easeInOut(duration: 0.25), value: isTabBarHidden)
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionView()
                .environmentObject(transactionVM)
                .environmentObject(authVM)
        }
        .task {
            if let p = authVM.userProfile {
                await transactionVM.refreshData(userId: p.id, userType: p.userType ?? "personal")
                await scheduledPaymentVM.fetchScheduledPayments(userId: p.id)
            }
        }
        .onChange(of: authVM.userProfile) { _, p in
            if let p {
                Task {
                    await transactionVM.refreshData(userId: p.id, userType: p.userType ?? "personal")
                    await scheduledPaymentVM.fetchScheduledPayments(userId: p.id)
                }
            }
        }
        .onChange(of: selectedTab) { _, _ in
            // Tab değiştiğinde tab bar'ı göster
            withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
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
                    .frame(width: 56, height: 56)
                    .shadow(color: ZColor.indigo.opacity(scheme == .dark ? 0.6 : 0.38), radius: 14, y: 5)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(FABButtonStyle())
        .accessibilityLabel(NSLocalizedString("dashboard.addTransaction", comment: ""))
    }
}
