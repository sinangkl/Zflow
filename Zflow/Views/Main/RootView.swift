import SwiftUI

// MARK: - Root View
// HIG: 5-tab layout with center + button (classic Apple style)

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @StateObject private var scheduledPaymentVM = ScheduledPaymentViewModel()
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showAddSheet = false
    @State private var showAIChat = false
    @State private var showActionMenu = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView(
                    onAddTapped: { showActionMenu = true },
                    onScrollChanged: { _ in },
                    onSeeAllTransactions: { selectedTab = 1 }  // "Tümünü Gör" → Reports tab
                )
                .environmentObject(scheduledPaymentVM)
                .tabItem { Label(NSLocalizedString("tab.home", comment: ""), systemImage: "house.fill") }
                .tag(0)

                // Reports + Transactions hub
                TransactionsReportsView()
                    .environmentObject(scheduledPaymentVM)
                    .tabItem { Label(NSLocalizedString("tab.reports", comment: ""), systemImage: "chart.bar.xaxis.ascending.badge.clock") }
                    .tag(1)

                // Center placeholder — intercepted by onChange
                Color.clear
                    .tabItem {
                        Label(NSLocalizedString("tab.add", comment: ""), systemImage: "plus.circle.fill")
                    }
                    .tag(2)

                CalendarView()
                    .environmentObject(scheduledPaymentVM)
                    .tabItem { Label(NSLocalizedString("tab.calendar", comment: ""), systemImage: "calendar") }
                    .tag(3)

                SettingsView()
                    .tabItem { Label(NSLocalizedString("tab.settings", comment: ""), systemImage: "gearshape.fill") }
                    .tag(4)
            }
            .tint(ZColor.indigo)
            .onChange(of: selectedTab) { _, newTab in
                if newTab == 2 {
                    selectedTab = previousTab
                    Haptic.medium()
                    showActionMenu = true
                } else {
                    previousTab = newTab
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionView()
                .environmentObject(transactionVM)
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showAIChat) {
            AIChatView()
                .environmentObject(transactionVM)
                .environmentObject(authVM)
        }
        .confirmationDialog(
            NSLocalizedString("action.chooseOption", comment: ""),
            isPresented: $showActionMenu,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("action.addTransaction", comment: "")) {
                showAddSheet = true
            }
            Button(NSLocalizedString("action.scanWithAI", comment: "")) {
                showAIChat = true
            }
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
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
    }
}
