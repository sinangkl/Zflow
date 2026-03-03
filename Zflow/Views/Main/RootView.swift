import SwiftUI

// MARK: - Root View
// HIG: 5-tab layout with floating glass tab bar and center + glow button

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @StateObject private var scheduledPaymentVM = ScheduledPaymentViewModel()
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var showAIChat = false
    @State private var showActionMenu = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case 0:
                    DashboardView(
                        onAddTapped: { showActionMenu = true },
                        onScrollChanged: { _ in },
                        onSeeAllTransactions: { selectedTab = 1 }
                    )
                    .environmentObject(scheduledPaymentVM)
                case 1:
                    TransactionsReportsView()
                        .environmentObject(scheduledPaymentVM)
                case 3:
                    CalendarView()
                        .environmentObject(scheduledPaymentVM)
                case 4:
                    SettingsView()
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating Tab Bar
            FloatingTabBar(
                selectedTab: $selectedTab,
                onAddTapped: {
                    Haptic.medium()
                    showActionMenu = true
                }
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard)
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

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    var onAddTapped: () -> Void
    @Environment(\.colorScheme) var scheme
    @Namespace private var tabNS

    private let tabs: [(Int, String, String)] = [
        (0, "house.fill", "tab.home"),
        (1, "chart.bar.xaxis.ascending.badge.clock", "tab.reports"),
        (3, "calendar", "tab.calendar"),
        (4, "gearshape.fill", "tab.settings")
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Left tabs
            ForEach(tabs.prefix(2), id: \.0) { tab in
                tabButton(tab: tab)
            }

            // Center + button with glow
            Button(action: onAddTapped) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentGradient)
                        .frame(width: 52, height: 52)
                        .shadow(color: ZColor.indigo.opacity(0.4), radius: 12, x: 0, y: 4)
                        .shadow(color: ZColor.indigo.opacity(0.2), radius: 24, x: 0, y: 8)

                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -8)
            .frame(maxWidth: .infinity)

            // Right tabs
            ForEach(tabs.suffix(2), id: \.0) { tab in
                tabButton(tab: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.7))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    scheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.08), radius: 16, x: 0, y: 8)
    }

    private func tabButton(tab: (Int, String, String)) -> some View {
        let (idx, icon, locKey) = tab
        let isSelected = selectedTab == idx
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = idx
            }
            Haptic.selection()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(ZColor.indigo.opacity(0.12))
                            .frame(width: 36, height: 36)
                            .matchedGeometryEffect(id: "tabBG", in: tabNS)
                    }
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 17 : 18, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? ZColor.indigo : ZColor.labelTert)
                }
                .frame(height: 36)

                Text(NSLocalizedString(locKey, comment: ""))
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? ZColor.indigo : ZColor.labelTert)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
