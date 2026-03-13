import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root View
// HIG: Adaptive layout — iPhone = floating glass tab bar, iPad/Mac = custom sidebar panel

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var scheduledPaymentVM: ScheduledPaymentViewModel
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @EnvironmentObject var calMgr: CalendarManager
    @EnvironmentObject var familyVM: FamilyViewModel
    @EnvironmentObject var activityVM: FamilyActivityViewModel
    @EnvironmentObject var goalVM: GoalViewModel
    @SceneStorage("selectedTab") private var selectedTab = 0
    @State private var showAddSheet   = false
    @State private var showAIChat     = false
    @State private var showActionMenu = false
    @State private var showFileImporter = false
    @State private var showBulkImport = false
    @State private var selectedImportURL: URL?
    @AppStorage("profileCardColor") private var appThemeColorHex: String = "#5E5CE6"
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var deepLinkFamilyID: String? = nil
    @State private var showFamilySheet = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadBody
            } else {
                iPhoneBody
            }
        }
        .fullScreenCover(isPresented: $showAddSheet) { addSheet }
        .sheet(isPresented: $showAIChat)     { aiSheet }
        .sheet(isPresented: $showActionMenu) { actionSheet }
        .sheet(isPresented: $showFamilySheet) {
            FamilyBudgetView(deepLinkFamilyID: deepLinkFamilyID)
                .environmentObject(authVM)
                .environmentObject(familyVM)
                .environmentObject(activityVM)
                .environmentObject(goalVM)
                .environmentObject(budgetManager)
                .environmentObject(transactionVM)
        }

        .fullScreenCover(isPresented: $showBulkImport) {
            if let url = selectedImportURL {
                BulkImportView(
                    viewModel: BulkImportViewModel(categories: transactionVM.categories),
                    fileURL: url
                )
                .environmentObject(transactionVM)
                .environmentObject(authVM)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                selectedImportURL = url
                showBulkImport = true
            }
        }
        .task { await loadData() }
        .onChange(of: authVM.userProfile) { _, p in
            guard let p else { return }
            Task {
                await transactionVM.refreshData(userId: p.id, userType: p.userType ?? "personal")
                await scheduledPaymentVM.fetchScheduledPayments(userId: p.id)
                await budgetManager.fetchBudgets(userId: p.id)
                await recurringVM.fetchAll(userId: p.id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .zflowOpenAddSheet)) { _ in
            showAddSheet = true
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Deep link format: zflow://family/invite?id=... or zflow://family/share?id=...
        guard url.scheme == "zflow", url.host == "family" else { return }
        
        let path = url.path
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let id = components?.queryItems?.first(where: { $0.name == "id" })?.value
        
        Haptic.success()
        
        if path.contains("invite") || path.contains("share") {
            deepLinkFamilyID = id
            // Switch to Settings tab (index 4)
            selectedTab = 4
            // We can show a specialized sheet or let SettingsView handle it
            showFamilySheet = true
        }
    }

    // MARK: - Data Load

    private func loadData() async {
        if let p = authVM.userProfile {
            await transactionVM.refreshData(userId: p.id, userType: p.userType ?? "personal")
            await scheduledPaymentVM.fetchScheduledPayments(userId: p.id)
            await budgetManager.fetchBudgets(userId: p.id)
            await recurringVM.fetchAll(userId: p.id)
        }
        await calMgr.requestAccess()
    }

    // MARK: - iPhone Body

    private var iPhoneBody: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .transaction { $0.animation = nil }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(
                selectedTab: $selectedTab,
                onAddTapped: {
                    Haptic.medium()
                    showActionMenu = true
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // AI Sparkle Floating Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showAIChat = true
                        Haptic.medium()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accentGradient)
                                .frame(width: 56, height: 56)
                                .shadow(color: AppTheme.baseColor.opacity(0.4), radius: 12, x: 0, y: 8)
                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 24)
                    .padding(.bottom, 110)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - iPad / Mac Body

    private var iPadBody: some View {
        NavigationSplitView {
            iPadSidebar
                .navigationTitle("ZFlow")
        } detail: {
            tabContent
                .navigationTitle(navTitleForTab(selectedTab))
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func navTitleForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return NSLocalizedString("tab.home", comment: "")
        case 1: return NSLocalizedString("tab.reports", comment: "")
        case 3: return NSLocalizedString("tab.calendar", comment: "")
        case 4: return NSLocalizedString("tab.settings", comment: "")
        default: return ""
        }
    }

    // MARK: - iPad Sidebar

    private var iPadSidebar: some View {
        let accent = Color(hex: appThemeColorHex)
        return ZStack(alignment: .topLeading) {
            MeshGradientBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── App Logo & Actions ────────────────────────────────
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [accent, accent.opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                            .shadow(color: accent.opacity(0.45), radius: 10, y: 4)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("ZFlow")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [accent, accent.opacity(0.75)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))

                    Spacer()

                    // AI + Add buttons
                    HStack(spacing: 6) {
                        Button {
                            showAIChat = true
                            Haptic.medium()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(accent.opacity(0.14))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(accent)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            showActionMenu = true
                            Haptic.medium()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [accent, accent.opacity(0.75)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 32, height: 32)
                                    .shadow(color: accent.opacity(0.35), radius: 6, y: 3)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 28)
                .padding(.bottom, 16)

                // ── User Info ─────────────────────────────────────────
                if let profile = authVM.userProfile,
                   let name = profile.fullName, !name.isEmpty {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.15))
                                .frame(width: 30, height: 30)
                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(accent)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(profile.userType == "business"
                                 ? NSLocalizedString("settings.business", comment: "")
                                 : NSLocalizedString("settings.personal", comment: ""))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }

                // ── Divider ───────────────────────────────────────────
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 0.5)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                // ── Navigation Items ──────────────────────────────────
                VStack(spacing: 2) {
                    sidebarItem(tab: 0, icon: "house.fill",
                                label: NSLocalizedString("tab.home",     comment: ""))
                    sidebarItem(tab: 1, icon: "chart.bar.xaxis.ascending.badge.clock",
                                label: NSLocalizedString("tab.reports",  comment: ""))
                    sidebarItem(tab: 3, icon: "calendar",
                                label: NSLocalizedString("tab.calendar", comment: ""))
                    sidebarItem(tab: 4, icon: "gearshape.fill",
                                label: NSLocalizedString("tab.settings", comment: ""))
                }
                .padding(.horizontal, 10)

                Spacer()
            }
        }
    }

    private func sidebarItem(tab: Int, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        let accent = Color(hex: appThemeColorHex)
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedTab = tab
            }
            Haptic.selection()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(accent.opacity(0.16))
                            .frame(width: 32, height: 32)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? accent : .secondary)
                }
                .frame(width: 32, height: 32)

                Text(label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? accent : .primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accent.opacity(0.09))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isSelected)
    }

    // MARK: - Shared Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            DashboardView(
                onAddTapped:          { showActionMenu = true },
                onChatTapped:         { showAIChat = true },
                onScrollChanged:      { _ in },
                onSeeAllTransactions: { selectedTab = 1 }
            )
            .environmentObject(scheduledPaymentVM)
            .environmentObject(recurringVM)
            .environmentObject(calMgr)
            .environmentObject(goalVM)
        case 1:
            TransactionsReportsView(onAddTapped: { showActionMenu = true })
                .environmentObject(scheduledPaymentVM)
                .environmentObject(calMgr)
        case 3:
            CalendarView()
                .environmentObject(scheduledPaymentVM)
                .environmentObject(recurringVM)
                .environmentObject(calMgr)
        case 4:
            SettingsView()
                .environmentObject(recurringVM)
        default:
            EmptyView()
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder private var addSheet: some View {
        AddTransactionView()
            .environmentObject(transactionVM)
            .environmentObject(authVM)
            .environmentObject(scheduledPaymentVM)
            .environmentObject(calMgr)
    }

    @ViewBuilder private var aiSheet: some View {
        AIChatView()
            .environmentObject(transactionVM)
            .environmentObject(authVM)
            .environmentObject(scheduledPaymentVM)
            .environmentObject(budgetManager)
            .environmentObject(calMgr)
    }

    @ViewBuilder private var actionSheet: some View {
        ActionMenuSheet(
            onAddTransaction: {
                showActionMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showAddSheet = true }
            },
            onScanAI: {
                showActionMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showAIChat = true }
            },
            onAddFile: {
                showActionMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showFileImporter = true }
            }
        )
        .presentationDetents([.height(310)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    var onAddTapped: () -> Void
    @Environment(\.colorScheme) var scheme
    @Namespace private var tabNS
    @State private var isAddPressed = false
    @AppStorage("profileCardColor") private var appThemeColorHex: String = "#5E5CE6"

    private let tabs: [(Int, String, String)] = [
        (0, "house.fill",                              "tab.home"),
        (1, "chart.bar.xaxis.ascending.badge.clock",   "tab.reports"),
        (3, "calendar",                                "tab.calendar"),
        (4, "gearshape.fill",                          "tab.settings")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.prefix(2), id: \.0) { tab in tabButton(tab: tab) }

            // Center + button with glow
            Button { onAddTapped() } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentGradient)
                        .frame(width: 52, height: 52)
                        .shadow(color: Color(hex: appThemeColorHex).opacity(isAddPressed ? 0.6 : 0.4),
                                radius: isAddPressed ? 8 : 12, x: 0, y: isAddPressed ? 2 : 4)
                        .shadow(color: Color(hex: appThemeColorHex).opacity(isAddPressed ? 0.35 : 0.2),
                                radius: isAddPressed ? 16 : 24, x: 0, y: isAddPressed ? 4 : 8)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isAddPressed ? 90 : 0))
                }
                .scaleEffect(isAddPressed ? 0.88 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isAddPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isAddPressed = true }
                    .onEnded   { _ in isAddPressed = false }
            )
            .offset(y: -8)
            .frame(maxWidth: .infinity)

            ForEach(tabs.suffix(2), id: \.0) { tab in tabButton(tab: tab) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.70))
            }
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 20, x: 0, y: 10)
    }

    private func tabButton(tab: (Int, String, String)) -> some View {
        let (idx, icon, locKey) = tab
        let isSelected   = selectedTab == idx
        let inactiveColor = scheme == .dark ? Color.white.opacity(0.5) : Color.gray.opacity(0.6)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = idx }
            Haptic.selection()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color(hex: appThemeColorHex).opacity(0.14))
                            .frame(width: 38, height: 38)
                            .matchedGeometryEffect(id: "tabBG", in: tabNS)
                    }
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 17 : 18, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? Color(hex: appThemeColorHex) : inactiveColor)
                }
                .frame(width: 44, height: 38)

                Text(NSLocalizedString(locKey, comment: ""))
                    .font(.system(size: 10, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? Color(hex: appThemeColorHex) : inactiveColor)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Menu Sheet

struct ActionMenuSheet: View {
    var onAddTransaction: () -> Void
    var onScanAI: () -> Void
    var onAddFile: () -> Void
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text(NSLocalizedString("action.chooseOption", comment: ""))
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(scheme == .dark ? .white : ZColor.label)
                .padding(.top, 4)

            VStack(spacing: 14) {
                actionButton(
                    title: NSLocalizedString("action.addTransaction", comment: ""),
                    icon: "plus.circle.fill",
                    gradient: AppTheme.accentGradient,
                    action: onAddTransaction
                )
                actionButton(
                    title: NSLocalizedString("action.scanWithAI", comment: ""),
                    icon: "sparkles",
                    gradient: LinearGradient(
                        colors: [Color(hex: "#8A2BE2"), Color(hex: "#FF1493")],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    action: onScanAI
                )
                actionButton(
                    title: NSLocalizedString("action.addFile", comment: ""),
                    icon: "doc.badge.plus",
                    gradient: LinearGradient(
                        colors: [ZColor.burgundy, Color(hex: "#800000")],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    action: onAddFile
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .background(
            ZStack {
                MeshGradientBackground()
                    .opacity(0.8)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func actionButton(title: String, icon: String,
                               gradient: LinearGradient, action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.selection(); action() }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.3))
            }
            .padding(14)
            .liquidGlass(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }
}
