import SwiftUI
import Supabase
import PostgREST

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @EnvironmentObject var scheduledPaymentVM: ScheduledPaymentViewModel
    @EnvironmentObject var walletPassManager: WalletPassManager
    @EnvironmentObject var goalVM: GoalViewModel
    @EnvironmentObject var familyVM: FamilyViewModel
    @EnvironmentObject var activityVM: FamilyActivityViewModel
    @Environment(\.colorScheme) var scheme

    @AppStorage("defaultCurrency") private var defaultCurrency: String = "TRY"
    @AppStorage("appColorScheme")  private var appColorScheme: String  = "system"
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var showEditProfile     = false
    @State private var showBudgetManager   = false
    @State private var showCategoryMgr     = false
    @State private var showExport          = false
    @State private var showRecurringManager = false
    @State private var showSignOutAlert    = false
    @State private var showGoals           = false
    @State private var showFamilyBudget    = false
    @State private var showCashFlow        = false
    @State private var showThemeSettings   = false

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        profileCard
                        appearanceSection
                        preferencesSection
                        budgetSection
                        recurringSection
                        goalsSection
                        if authVM.userProfile?.isBusiness == true {
                            VATPreviewCard()
                                .environmentObject(transactionVM)
                        }
                        walletSection
                        familySection
                        dataSection
                        dangerSection
                        versionFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 85)
                }
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditProfile)   { EditProfileView().environmentObject(authVM) }
            .sheet(isPresented: $showBudgetManager) {
                BudgetManagerView()
                    .environmentObject(transactionVM)
                    .environmentObject(budgetManager)
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showCategoryMgr) {
                CategoryManagerView()
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showExport) {
                ExportView().environmentObject(transactionVM)
            }
            .sheet(isPresented: $showRecurringManager) {
                RecurringManagerView()
                    .environmentObject(authVM)
                    .environmentObject(transactionVM)
                    .environmentObject(recurringVM)
            }
            .sheet(isPresented: $showGoals) {
                GoalsView()
                    .environmentObject(authVM)
                    .environmentObject(goalVM)
            }
            .sheet(isPresented: $showFamilyBudget) {
                FamilyBudgetView()
                    .environmentObject(authVM)
                    .environmentObject(budgetManager)
                    .environmentObject(familyVM)
                    .environmentObject(transactionVM)
                    .environmentObject(goalVM)
                    .environmentObject(activityVM)
            }
            .sheet(isPresented: $showCashFlow) {
                CashFlowForecastView()
                    .environmentObject(transactionVM)
                    .environmentObject(recurringVM)
                    .environmentObject(scheduledPaymentVM)
            }
            .sheet(isPresented: $showThemeSettings) {
                ThemeSettingsView()
                    .environmentObject(authVM)
                    .environmentObject(familyVM)
                    .environmentObject(walletPassManager)
            }
            .alert(NSLocalizedString("settings.signOut", comment: ""), isPresented: $showSignOutAlert) {
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("settings.signOut", comment: ""), role: .destructive) {
                    Task { await authVM.signOut() }
                }
            } message: {
                Text(NSLocalizedString("settings.signOutConfirm", comment: ""))
            }
            // Wallet pass errors are logged silently — server may not be available
        }
    }

    // MARK: - Profile Card (Madde 8: Profil fotoğrafı destekli)

    private var profileCard: some View {
        GradientCard(gradient: AppTheme.accentGradient, cornerRadius: 20) {
            VStack(spacing: 16) {
                // Avatar
                Button {
                    showEditProfile = true; Haptic.light()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.20))
                            .frame(width: 80, height: 80)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5))

                        if let avatarData = authVM.userAvatarData,
                           let uiImage = UIImage(data: avatarData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            Text(authVM.userProfile?.initials ?? "Z")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(.white)
                        }

                        // Edit badge
                        Circle()
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.baseColor)
                            )
                            .offset(x: 26, y: 26)
                    }
                }
                .accessibilityLabel("Edit profile and avatar")

                VStack(spacing: 5) {
                    Text(authVM.userProfile?.displayName ?? "User")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Image(systemName: UserType(rawValue: authVM.userProfile?.userType ?? "personal")?.icon ?? "person.fill")
                            .font(.system(size: 11))
                        Text(authVM.userProfile?.userType == "business"
                             ? Localizer.shared.l("auth.business")
                             : Localizer.shared.l("auth.personal"))
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.white.opacity(0.78))

                    if let biz = authVM.userProfile?.businessName {
                        Text(biz)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.60))
                    }
                }

                Button {
                    showEditProfile = true; Haptic.light()
                } label: {
                    Text(NSLocalizedString("settings.editProfile", comment: ""))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.38), lineWidth: 1))
                }
                .accessibilityLabel("Open edit profile dialog")
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        settingsSection(NSLocalizedString("settings.appearance", comment: "")) {
            settingsRow(icon: "moon.stars.fill", iconColor: ZColor.purple, title: "Tema & Görünüm") {
                Button {
                    showThemeSettings = true
                } label: {
                    HStack {
                        Text(appColorScheme == "system" ? "Sistem" : (appColorScheme == "light" ? "Açık" : "Koyu"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var preferencesSection: some View {
        settingsSection(NSLocalizedString("settings.preferences", comment: "")) {
            VStack(spacing: 0) {
                settingsRow(icon: "dollarsign.circle.fill", iconColor: ZColor.income,
                            title: NSLocalizedString("settings.defaultCurrency", comment: "")) {
                    Picker("", selection: $defaultCurrency) {
                        ForEach(Currency.allCases) { cur in
                            Text("\(cur.flag) \(cur.rawValue)").tag(cur.rawValue)
                        }
                    }
                    .tint(.primary)
                }
                divider
                settingsRow(icon: "lock.fill", iconColor: AppTheme.baseColor, title: NSLocalizedString("settings.staySignedIn", comment: "")) {
                    Toggle("", isOn: $authVM.rememberMe).labelsHidden()
                }
                divider
                settingsRow(icon: "globe", iconColor: ZColor.neonPurple, title: NSLocalizedString("settings.language", comment: "")) {
                    Picker("", selection: $languageManager.currentLanguage) {
                        ForEach(AppLanguage.allLanguages) { lang in
                            Text("\(lang.flag) \(lang.displayName)").tag(lang.code)
                        }
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private var budgetSection: some View {
        settingsSection(NSLocalizedString("settings.manageBudgets", comment: "")) {
            VStack(spacing: 0) {
                navRow(icon: "target", iconColor: ZColor.amber,
                       title: NSLocalizedString("settings.manageBudgets", comment: ""),
                       badge: budgetManager.budgets.isEmpty ? nil : "\(budgetManager.budgets.count) active") {
                    showBudgetManager = true; Haptic.light()
                }
                divider
                navRow(icon: "tag.fill", iconColor: ZColor.neonPink,
                       title: NSLocalizedString("settings.manageCategories", comment: ""),
                       badge: "\(transactionVM.categories.count)") {
                    showCategoryMgr = true; Haptic.light()
                }
            }
        }
    }

    // MARK: - Goals & Cash Flow
    private var goalsSection: some View {
        settingsSection("Finansal Planlama") {
            VStack(spacing: 0) {
                navRow(
                    icon: "star.circle.fill",
                    iconColor: Color(hex: "#FF9F0A"),
                    title: "Finansal Hedefler",
                    badge: goalVM.goals.isEmpty ? nil : "\(goalVM.goals.count)"
                ) {
                    showGoals = true; Haptic.light()
                }
                Divider().padding(.leading, 52)
                navRow(
                    icon: "chart.xyaxis.line",
                    iconColor: Color(hex: "#30D158"),
                    title: "Nakit Akışı Tahmini",
                    badge: nil
                ) {
                    showCashFlow = true; Haptic.light()
                }
            }
        }
    }

    // MARK: - Apple Family
    private var familySection: some View {
        settingsSection("Aile & Paylaşım") {
            navRow(
                icon: "house.circle.fill",
                iconColor: Color(hex: "#FF6B6B"),
                title: "Aile Bütçesi",
                badge: nil
            ) {
                showFamilyBudget = true; Haptic.light()
            }
        }
    }

    /// Düzenli ödemeleri yönet
    private var recurringSection: some View {

        settingsSection(NSLocalizedString("settings.recurring.manage", comment: "")) {
            navRow(
                icon: "repeat.circle.fill",
                iconColor: ZColor.neonPurple,
                title: NSLocalizedString("settings.recurring.manage", comment: ""),
                badge: recurringVM.activeTransactions.isEmpty ? nil : "\(recurringVM.activeTransactions.count)"
            ) {
                showRecurringManager = true
                Haptic.light()
            }
        }
    }

    // MARK: - Apple Ecosystem Integrations
    private var walletSection: some View {
        settingsSection(NSLocalizedString("settings.appleWallet", value: "Apple Wallet (Yakında)", comment: "")) {
            VStack(spacing: 0) {
                // Feature: Generate ZFlow Wallet Pass (Temporarily Disabled)
                HStack(spacing: 14) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.3))) // Dimmed icon background
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add ZFlow to Wallet")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        Text("View budget limits instantly")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    Spacer()
                    Button {
                        // Action temporarily disabled
                        Haptic.error()
                    } label: {
                        Text("Yakında")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.3))) // Dimmed button background
                    }
                    .disabled(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
        }
        .opacity(0.6) // Dim entire section to show it's disabled
    }

    private var dataSection: some View {
        settingsSection(NSLocalizedString("settings.exportData", comment: "")) {
            navRow(icon: "square.and.arrow.up.fill", iconColor: ZColor.teal,
                   title: NSLocalizedString("settings.exportData", comment: ""), badge: nil) {
                showExport = true; Haptic.light()
            }
        }
    }

    private var dangerSection: some View {
        settingsSection(NSLocalizedString("settings.signOut", comment: "")) {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.red.opacity(0.1)))
                Text(NSLocalizedString("settings.signOut", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showSignOutAlert = true; Haptic.warning()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("ZFlow")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            Text(Localizer.shared.l("settings.appVersion"))
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().padding(.leading, 58)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 6)

            GlassCard(cornerRadius: 16) { content() }
        }
    }

    private func settingsRow<Trailing: View>(icon: String, iconColor: Color, title: String,
                                             @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(iconColor.opacity(0.12)))
            Text(title)
                .font(.system(size: 15))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func navRow(icon: String, iconColor: Color, title: String, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(iconColor.opacity(0.12)))
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                if let b = badge {
                    Text(b)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color(.systemGray5)))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Edit Profile View (Madde 8: Profil fotoğrafı, PhotosUI)

import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    @State private var profileCardColorHex: String = UserDefaults.standard.string(forKey: "profileCardColor") ?? "#5E5CE6"
    @State private var showChangeEmail = false
    @State private var showChangePassword = false
    
    // Original State Properties
    @State private var fullName       = ""
    @State private var phoneNumber    = ""
    @State private var businessName   = ""
    @State private var isSaving       = false
    @State private var photosItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @ObservedObject private var securityManager = ZFlowSecurityManager.shared

    private var isBusiness: Bool { authVM.userProfile?.isBusiness == true }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        personalInfoSection
                        securitySection
                        saveButtonSection
                        Spacer()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("settings.editProfile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
            .onAppear(perform: loadCurrentProfile)
            .onChange(of: photosItem) { _, newItem in handlePhotoSelection(newItem) }
            .sheet(isPresented: $showChangeEmail) { ChangeEmailView().environmentObject(authVM) }
            .sheet(isPresented: $showChangePassword) { ChangePasswordView().environmentObject(authVM) }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        SettingsProfileCard(
            fullName: fullName,
            email: authVM.currentUserEmail ?? "No Email",
            userType: authVM.userProfile?.userType ?? "personal",
            initials: authVM.userProfile?.initials ?? "Z",
            avatarData: selectedImageData,
            colorHex: profileCardColorHex,
            onPhotoSelect: { self.photosItem = $0 },
            photosItem: $photosItem
        )
        .padding(.top, 16)
        .padding(.horizontal)
    }

    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("settings.personalInfo", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ZColor.labelSec)
                .textCase(.uppercase)
                .padding(.leading, 16)
                
            VStack(spacing: 0) {
                formRow(icon: "person.fill", placeholder: NSLocalizedString("auth.fullName", comment: ""), text: $fullName)
                Divider().padding(.leading, 50)
                formRow(icon: "phone.fill", placeholder: NSLocalizedString("auth.phoneNumber", comment: ""), text: $phoneNumber)

                if isBusiness {
                    Divider().padding(.leading, 50)
                    formRow(icon: "building.2.fill", placeholder: NSLocalizedString("auth.businessName", comment: ""), text: $businessName)
                }
            }
            .liquidGlass(cornerRadius: 16)
        }
        .padding(.horizontal)
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("settings.security", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ZColor.labelSec)
                .textCase(.uppercase)
                .padding(.leading, 16)
            
            VStack(spacing: 0) {
                actionRow(icon: "envelope.fill", label: NSLocalizedString("settings.changeEmail", comment: ""), value: authVM.currentUserEmail ?? "") {
                    showChangeEmail = true
                }
                Divider().padding(.leading, 50)
                actionRow(icon: "lock.fill", label: NSLocalizedString("settings.changePassword", comment: ""), value: "••••••••") {
                    showChangePassword = true
                }
                Divider().padding(.leading, 50)
                settingsRow(icon: "faceid", iconColor: AppTheme.baseColor, title: NSLocalizedString("settings.appLock", comment: "")) {
                    Toggle("", isOn: $securityManager.isLockEnabled)
                        .labelsHidden()
                        .onChange(of: securityManager.isLockEnabled) { _, newValue in
                            if newValue {
                                securityManager.authenticate { _ in }
                            }
                        }
                }
            }
            .liquidGlass(cornerRadius: 16)
        }
        .padding(.horizontal)
    }

    private var saveButtonSection: some View {
        Button(action: saveProfile) {
            ZStack {
                if isSaving { ProgressView().tint(.white) }
                else {
                    Text(NSLocalizedString("settings.saveChanges", comment: ""))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(saveButtonBackground)
            .shadow(color: Color(hex: profileCardColorHex).opacity(fullName.isEmpty ? 0 : 0.35), radius: 12, y: 4)
        }
        .disabled(fullName.isEmpty || isSaving)
        .padding(.horizontal)
    }

    private var saveButtonBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(fullName.isEmpty || isSaving
                  ? AnyShapeStyle(Color(hex: profileCardColorHex).opacity(0.45))
                  : AnyShapeStyle(LinearGradient(colors: [Color(hex: profileCardColorHex), Color(hex: profileCardColorHex).opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    // MARK: - Logic

    private func loadCurrentProfile() {
        fullName     = authVM.userProfile?.fullName ?? ""
        phoneNumber  = authVM.userProfile?.phoneNumber ?? ""
        businessName = authVM.userProfile?.businessName ?? ""
        selectedImageData = authVM.userAvatarData
    }

    private func handlePhotoSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                selectedImageData = data
            }
        }
    }

    private func saveProfile() {
        isSaving = true
        Task {
            // Save global theme color
            UserDefaults.standard.set(profileCardColorHex, forKey: "profileCardColor")
            transactionVM.updateEcosystem()
            
            // Upload photo if changed
            if let imgData = selectedImageData {
                await authVM.uploadAvatar(data: imgData)
            }
            let ok = await authVM.updateProfile(
                fullName: fullName,
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                businessName: isBusiness ? businessName : nil)
            isSaving = false
            if ok { dismiss() }
        }
    }

    private func actionRow(icon: String, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.baseColor)
                    .frame(width: 20)
                    .padding(.leading, 16)
                
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(ZColor.label)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(ZColor.labelSec)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ZColor.labelSec.opacity(0.5))
                    .padding(.trailing, 16)
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
    }

    private func formRow(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.baseColor)
                .frame(width: 20)
                .padding(.leading, 16)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                // No inner background — seamlessly transparent inside the liquidGlass container
        }
        .frame(minHeight: 52)
        .padding(.trailing, 16)
    }

    private func settingsRow<Trailing: View>(icon: String, iconColor: Color, title: String,
                                             @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 20)
                .padding(.leading, 16)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(ZColor.label)
            
            Spacer()
            
            trailing()
                .padding(.trailing, 16)
        }
        .frame(minHeight: 52)
    }
}

// MARK: - Profile Card Component

struct SettingsProfileCard: View {
    @Environment(\.colorScheme) var scheme
    
    let fullName: String
    let email: String
    let userType: String
    let initials: String
    let avatarData: Data?
    let colorHex: String
    
    var onPhotoSelect: (PhotosPickerItem?) -> Void
    @Binding var photosItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex).opacity(0.25))
                        .frame(width: 72, height: 72)

                    if let data = avatarData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                    } else {
                        Text(initials)
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(Color(hex: colorHex))
                    }
                }
                .overlay(Circle().strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 1.5))

                // Camera badge
                PhotosPicker(selection: $photosItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 24, height: 24)
                            .shadow(color: Color(hex: colorHex).opacity(0.4), radius: 4, y: 1)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .onChange(of: photosItem) { _, newItem in
                onPhotoSelect(newItem)
            }

            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(fullName.isEmpty ? "My Profile" : fullName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(email)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 4) {
                    Image(systemName: userType == "business" ? "building.2.fill" : "person.fill")
                        .font(.system(size: 10))
                    Text(userType.capitalized)
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .foregroundColor(.white)
                .padding(.top, 2)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color(hex: colorHex).opacity(0.9), Color(hex: colorHex).opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Light leak effect
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .offset(x: 80, y: -40)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: colorHex).opacity(0.3), radius: 16, y: 8)
    }
}

// MARK: - Change Email View

struct ChangeEmailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var newEmail = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Enter your new email address. You may be required to verify this address.")
                        .font(.system(size: 15))
                        .foregroundColor(ZColor.labelSec)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.baseColor)
                                .frame(width: 20)
                                .padding(.leading, 16)
                            TextField("New Email", text: $newEmail)
                                .font(.system(size: 16))
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        .frame(minHeight: 52)
                        .padding(.trailing, 16)
                    }
                    .liquidGlass(cornerRadius: 16)
                    .padding(.horizontal)
                    
                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ZColor.expense)
                            .padding(.horizontal)
                    }
                    
                    Button {
                        isSaving = true
                        Task {
                            let ok = await authVM.updateEmail(newEmail: newEmail)
                            isSaving = false
                            if ok { dismiss() }
                        }
                    } label: {
                        ZStack {
                            if isSaving { ProgressView().tint(.white) }
                            else {
                                Text(NSLocalizedString("settings.updateEmail", comment: ""))
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(newEmail.isEmpty || isSaving
                                      ? AnyShapeStyle(AppTheme.accentGradient.opacity(0.45))
                                      : AnyShapeStyle(AppTheme.accentGradient))
                        )
                        .shadow(color: AppTheme.baseColor.opacity(newEmail.isEmpty ? 0 : 0.35), radius: 12, y: 4)
                    }
                    .disabled(newEmail.isEmpty || isSaving)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle(NSLocalizedString("settings.changeEmail", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
            .onAppear {
                authVM.errorMessage = nil
            }
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme
    @EnvironmentObject var authVM: AuthViewModel

    @State private var newPassword     = ""
    @State private var confirmPassword = ""
    @State private var showNew         = false
    @State private var showConfirm     = false
    @State private var isSaving        = false
    @State private var localError: String?

    private var isDisabled: Bool { newPassword.isEmpty || confirmPassword.isEmpty || isSaving }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Header icon
                        ZStack {
                            Circle()
                                .fill(AppTheme.baseColor.opacity(scheme == .dark ? 0.18 : 0.10))
                                .frame(width: 88, height: 88)
                                .blur(radius: 1)
                            Circle()
                                .fill(scheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.90)))
                                .frame(width: 80, height: 80)
                                .overlay(Circle().strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), AppTheme.baseColor.opacity(0.2)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 0.8))
                                .shadow(color: AppTheme.baseColor.opacity(0.40), radius: 20, y: 6)
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(LinearGradient(
                                    colors: [AppTheme.baseColor, AppTheme.accentSecondary],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        .padding(.top, 36)

                        // Subtitle
                        Text(NSLocalizedString("auth.resetPasswordDesc", comment: ""))
                            .font(.system(size: 15))
                            .foregroundColor(scheme == .dark ? Color.white.opacity(0.50) : Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)

                        // Fields
                        VStack(spacing: 0) {
                            pwRow(
                                icon: "lock.fill",
                                placeholder: NSLocalizedString("settings.newPassword", comment: ""),
                                text: $newPassword,
                                show: $showNew
                            )
                            Rectangle()
                                .fill(scheme == .dark ? Color.white.opacity(0.07) : Color(.separator).opacity(0.4))
                                .frame(height: 0.5)
                                .padding(.leading, 50)
                            pwRow(
                                icon: "lock.badge.checkmark.fill",
                                placeholder: NSLocalizedString("settings.confirmPassword", comment: ""),
                                text: $confirmPassword,
                                show: $showConfirm
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(scheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.94)))
                                .shadow(color: scheme == .dark ? AppTheme.baseColor.opacity(0.12) : Color.black.opacity(0.06), radius: 20, y: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    scheme == .dark
                                        ? LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color.white.opacity(0.8), Color(.systemGray5).opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 0.8)
                        )
                        .padding(.horizontal, 20)

                        // Strength bar
                        if !newPassword.isEmpty {
                            strengthBar.padding(.horizontal, 20)
                        }

                        // Error
                        if let error = localError ?? authVM.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(ZColor.expense)
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // CTA button
                        Button { save() } label: {
                            ZStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(NSLocalizedString("auth.updatePassword", comment: ""))
                                            .font(.system(size: 17, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isDisabled
                                          ? AnyShapeStyle(AppTheme.accentGradient.opacity(0.40))
                                          : AnyShapeStyle(AppTheme.accentGradient))
                            )
                            .shadow(color: AppTheme.baseColor.opacity(isDisabled ? 0 : 0.40), radius: 14, y: 5)
                        }
                        .disabled(isDisabled)
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.18), value: isDisabled)
                        .buttonStyle(FABButtonStyle())

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("settings.changePassword", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
            .animation(.easeInOut(duration: 0.20), value: localError)
            .onAppear { authVM.errorMessage = nil }
        }
    }

    // MARK: - Password Row
    @ViewBuilder
    private func pwRow(icon: String, placeholder: String, text: Binding<String>, show: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LinearGradient(
                    colors: [AppTheme.baseColor, AppTheme.accentSecondary],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 20)
                .padding(.leading, 16)

            Group {
                if show.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(scheme == .dark ? .white : .primary)
            .textContentType(.newPassword)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Spacer()

            Button { show.wrappedValue.toggle(); Haptic.selection() } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(scheme == .dark ? Color.white.opacity(0.40) : Color(.tertiaryLabel))
                    .frame(width: 40, height: 40)
            }
        }
        .frame(minHeight: 54)
        .padding(.trailing, 4)
    }

    // MARK: - Strength Bar
    private var strengthBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < strengthLevel ? strengthColor : Color.secondary.opacity(0.20))
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.25), value: strengthLevel)
                }
            }
            Text(strengthLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(strengthColor)
        }
    }

    private var strengthLevel: Int {
        if newPassword.count == 0 { return 0 }
        if newPassword.count < 6  { return 1 }
        if newPassword.count < 10 { return 2 }
        return 3
    }

    private var strengthColor: Color {
        switch strengthLevel {
        case 1:  return ZColor.expense
        case 2:  return .orange
        default: return ZColor.income
        }
    }

    private var strengthLabel: String {
        switch strengthLevel {
        case 1:  return NSLocalizedString("auth.pwWeak",   comment: "")
        case 2:  return NSLocalizedString("auth.pwFair",   comment: "")
        case 3:  return NSLocalizedString("auth.pwStrong", comment: "")
        default: return ""
        }
    }

    // MARK: - Save
    private func save() {
        localError = nil
        guard newPassword.count >= 6 else {
            localError = NSLocalizedString("auth.passwordTooShort", comment: "")
            Haptic.error(); return
        }
        guard newPassword == confirmPassword else {
            localError = NSLocalizedString("auth.passwordMismatch", comment: "")
            Haptic.error(); return
        }
        isSaving = true
        Task {
            let ok = await authVM.updatePassword(newPassword: newPassword)
            isSaving = false
            if ok { dismiss() }
        }
    }
}

// MARK: - Budget Manager View

struct BudgetManagerView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    @State private var selectedCategory: Category?
    @State private var budgetText = ""
    @State private var showPaywall = false

    private var expenseCategories: [Category] {
        transactionVM.categories.filter { cat in
            cat.type == "expense" || cat.type == "both" || cat.type == nil
        }
    }

    @State private var settingSalary = false

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()

                Group {
                    if expenseCategories.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "target")
                                .font(.system(size: 52, weight: .light))
                                .foregroundStyle(AppTheme.accentGradient)
                            Text(NSLocalizedString("budget.noCategories", comment: "No categories yet"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(ZColor.label)
                            Text(NSLocalizedString("budget.noCategoriesHint", comment: "Add categories first"))
                                .font(.system(size: 14))
                                .foregroundColor(ZColor.labelSec)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                // Section 1: Total Income / Salary
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(NSLocalizedString("budget.totalIncome", comment: "Total Monthly Income"))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(ZColor.labelSec)
                                        .textCase(.uppercase)
                                        .padding(.leading, 4)
                                    
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(ZColor.income.opacity(0.15))
                                                .frame(width: 42, height: 42)
                                            Image(systemName: "banknote.fill")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(ZColor.income)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            if budgetManager.monthlySalary > 0 {
                                                Text(budgetManager.monthlySalary.formattedCurrency(code: transactionVM.primaryCurrency))
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(ZColor.label)
                                            } else {
                                                Text(NSLocalizedString("budget.notSet", comment: "Not set"))
                                                    .font(.system(size: 15))
                                                    .foregroundColor(ZColor.labelTert)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(ZColor.labelTert)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .liquidGlass(cornerRadius: 18)
                                    .onTapGesture {
                                        settingSalary = true
                                        budgetText = budgetManager.monthlySalary > 0 ? String(format: "%.0f", budgetManager.monthlySalary) : ""
                                        Haptic.selection()
                                    }
                                }

                                // Section 2: Category Budgets
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(NSLocalizedString("budget.categoryBudgets", comment: "Category Budgets"))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(ZColor.labelSec)
                                        .textCase(.uppercase)
                                        .padding(.leading, 4)
                                    
                                    VStack(spacing: 0) {
                                    ForEach(Array(expenseCategories.enumerated()), id: \.element.id) { idx, cat in
                                        let limit = budgetManager.budget(for: cat.id)
                                        let spent = transactionVM.categorySpending(categoryId: cat.id)

                                        budgetRow(cat: cat, limit: limit, spent: spent)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                let isNewBudget = limit == nil
                                                let isFreeTier = authVM.userProfile?.subscriptionTier == "free" || authVM.userProfile?.subscriptionTier == nil
                                                
                                                if isNewBudget && isFreeTier && budgetManager.budgets.count >= 3 {
                                                    showPaywall = true
                                                    Haptic.error()
                                                } else {
                                                    selectedCategory = cat
                                                    budgetText = limit.map { String(format: "%.0f", $0) } ?? ""
                                                    Haptic.selection()
                                                }
                                            }

                                        if idx < expenseCategories.count - 1 {
                                            Divider().padding(.leading, 62)
                                        }
                                    }
                                    }
                                    .liquidGlass(cornerRadius: 18)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("settings.manageBudgets", comment: "Category Budgets"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
            .alert(NSLocalizedString("budget.set", comment: "Set Budget"), isPresented: Binding(
                get: { selectedCategory != nil || settingSalary },
                set: { if !$0 { selectedCategory = nil; settingSalary = false } }
            )) {
                TextField(NSLocalizedString("budget.monthlyLimit", comment: "Monthly limit"), text: $budgetText)
                    .keyboardType(.decimalPad)
                Button(NSLocalizedString("common.save", comment: "Save")) {
                    if let userId = authVM.currentUserId {
                        if settingSalary {
                            let val = Double(budgetText.replacingOccurrences(of: ",", with: ".")) ?? 0
                            budgetManager.setMonthlySalary(userId: userId, salary: val, currency: transactionVM.primaryCurrency)
                        } else if let cat = selectedCategory {
                            if budgetText.isEmpty {
                                budgetManager.removeBudget(userId: userId, categoryId: cat.id)
                            } else if let val = Double(budgetText.replacingOccurrences(of: ",", with: ".")) {
                                budgetManager.setBudget(
                                    userId: userId,
                                    categoryId: cat.id,
                                    limit: val,
                                    currency: transactionVM.primaryCurrency
                                )
                            }
                        }
                        Haptic.success()
                    }
                    selectedCategory = nil
                    settingSalary = false
                }
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) { selectedCategory = nil; settingSalary = false }
            } message: {
                if settingSalary {
                    Text(NSLocalizedString("budget.enterSalary", comment: "Enter your total monthly income"))
                } else {
                    Text(String(format: NSLocalizedString("budget.limitFor", comment: "Monthly limit for %@"), selectedCategory?.name ?? ""))
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(authVM)
                    .presentationDetents([.fraction(0.9)])
            }
        }
    }

    private func budgetRow(cat: Category, limit: Double?, spent: Double) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: cat.color).opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: cat.icon ?? "circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: cat.color))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(cat.localizedName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ZColor.label)
                    if let l = limit {
                        Text("\(spent.formattedCurrency(code: transactionVM.primaryCurrency)) / \(l.formattedCurrency(code: transactionVM.primaryCurrency))")
                            .font(.system(size: 12))
                            .foregroundColor(ZColor.labelSec)
                    } else {
                        Text(NSLocalizedString("budget.notSet", comment: "No budget set"))
                            .font(.system(size: 12))
                            .foregroundColor(ZColor.labelTert)
                    }
                }
                Spacer()
                if let l = limit {
                    let ratio = l > 0 ? spent / l : 0
                    Circle()
                        .fill(budgetManager.statusColor(ratio: ratio))
                        .frame(width: 10, height: 10)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ZColor.labelTert)
            }
            if let l = limit {
                BudgetProgressBar(spent: spent, limit: l, color: Color(hex: cat.color), height: 5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Category Manager View

struct CategoryManagerView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showAdd       = false
    @State private var isRestoring   = false
    @State private var categoryToEdit: Category? = nil

    var body: some View {
        NavigationStack {
            Group {
                if transactionVM.categories.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(transactionVM.categories) { cat in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color(hex: cat.color).opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: cat.icon ?? "tag.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(Color(hex: cat.color))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cat.localizedName)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text((cat.type ?? "both").capitalized)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(typeColor(cat.type))
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Capsule().fill(typeColor(cat.type).opacity(0.12)))
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    categoryToEdit = cat
                                    Haptic.selection()
                                } label: {
                                    Label(NSLocalizedString("common.edit", comment: "Edit"), systemImage: "pencil.circle.fill")
                                }
                                .tint(AppTheme.baseColor)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    if let uid = authVM.currentUserId {
                                        Task { await transactionVM.deleteCategory(
                                            id: cat.id, userId: uid,
                                            userType: authVM.userProfile?.userType ?? "personal") }
                                        Haptic.medium()
                                    }
                                } label: { Label(NSLocalizedString("common.delete", comment: "Delete"), systemImage: "trash.fill") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.done", comment: "")) { dismiss() }.foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true; Haptic.light() } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(AppTheme.baseColor)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddCategorySheet()
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
            .sheet(item: $categoryToEdit) { cat in
                EditCategorySheet(category: cat)
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "tag.slash").font(.system(size: 52)).foregroundColor(ZColor.labelTert)
            Text(Localizer.shared.l("category.noCategories")).font(.system(size: 20, weight: .bold))
            Text(Localizer.shared.l("category.noCategoriesHint"))
                .font(.system(size: 14)).foregroundColor(ZColor.labelSec)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button {
                isRestoring = true
                Task { await restoreDefaults(); isRestoring = false }
            } label: {
                HStack(spacing: 8) {
                    if isRestoring { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.counterclockwise"); Text("Restore Defaults") }
                }
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(AppTheme.accentGradient).clipShape(Capsule())
            }
            .disabled(isRestoring)
            Spacer()
        }
    }

    private func typeColor(_ type: String?) -> Color {
        switch type {
        case "income": return ZColor.income
        case "expense": return ZColor.expense
        default: return AppTheme.baseColor
        }
    }

    private func restoreDefaults() async {
        guard let uid = authVM.currentUserId else { return }
        let userType = authVM.userProfile?.userType ?? "personal"
        let inserts = filteredDefaultCategories(for: userType).map {
            CategoryInsert(userId: uid, familyId: nil, name: $0.name, color: $0.color, icon: $0.icon, type: $0.type)
        }
        do {
            try await SupabaseManager.shared.client.from("categories").insert(inserts).execute()
            await transactionVM.fetchCategories(userId: uid, userType: userType)
        } catch { print("Restore error: \(error)") }
    }
}

// MARK: - Edit Category Sheet

struct EditCategorySheet: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    let category: Category

    @State private var name: String
    @State private var selectedColor: String
    @State private var selectedType: String
    @State private var isSaving = false

    init(category: Category) {
        self.category = category
        _name         = State(initialValue: category.name)
        _selectedColor = State(initialValue: category.color)
        _selectedType  = State(initialValue: category.type ?? "both")
    }

    private let colors: [String] = [
        "#34D399", "#10B981", "#60A5FA", "#3B82F6", "#8B5CF6",
        "#6366F1", "#EC4899", "#F472B6", "#F59E0B", "#FB923C",
        "#EF4444", "#FB7185", "#06B6D4", "#2DD4BF", "#84CC16"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(hex: selectedColor).opacity(0.18))
                            .frame(width: 80, height: 80)
                        Image(systemName: category.icon ?? "tag.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(Color(hex: selectedColor))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)

                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        label(Localizer.shared.l("common.name"))
                        TextField(Localizer.shared.l("category.namePlaceholder"), text: $name)
                            .font(.system(size: 16)).padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Type
                    VStack(alignment: .leading, spacing: 8) {
                        label(Localizer.shared.l("transaction.type"))
                        HStack(spacing: 8) {
                            typeChip("income",  Localizer.shared.l("transaction.income"),  "arrow.up.circle.fill",    ZColor.income)
                            typeChip("expense", Localizer.shared.l("transaction.expense"), "arrow.down.circle.fill",  ZColor.expense)
                            typeChip("both",    NSLocalizedString("settings.both", comment: ""),    "arrow.up.arrow.down",    AppTheme.baseColor)
                        }
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 10) {
                        label(Localizer.shared.l("common.color"))
                        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
                        LazyVGrid(columns: cols, spacing: 10) {
                            ForEach(colors, id: \.self) { hex in
                                let sel = selectedColor == hex
                                Button { withAnimation(.spring(response: 0.2)) { selectedColor = hex }; Haptic.selection() } label: {
                                    ZStack {
                                        Circle().fill(Color(hex: hex))
                                        if sel {
                                            Circle().strokeBorder(.white, lineWidth: 2.5)
                                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                        }
                                    }
                                    .frame(height: 44)
                                    .shadow(color: sel ? Color(hex: hex).opacity(0.5) : .clear, radius: 8, y: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16).padding(.bottom, 32)
            }
            .navigationTitle(NSLocalizedString("common.edit", comment: "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }.foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: {
                        if isSaving { ProgressView() }
                        else { Text(NSLocalizedString("common.save", comment: "")).bold() }
                    }
                    .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : AppTheme.baseColor)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary).tracking(0.5)
    }

    private func typeChip(_ val: String, _ lbl: String, _ icon: String, _ col: Color) -> some View {
        let sel = selectedType == val
        return Button { withAnimation(.spring(response: 0.25)) { selectedType = val }; Haptic.selection() } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(lbl).font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(sel ? col.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundColor(sel ? col : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(sel ? col.opacity(0.45) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let uid = authVM.currentUserId else { return }
        isSaving = true
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("categories")
                    .update(["name": trimmed, "color": selectedColor, "type": selectedType])
                    .eq("id", value: category.id.uuidString)
                    .execute()
                let userType = authVM.userProfile?.userType ?? "personal"
                await transactionVM.fetchCategories(userId: uid, userType: userType)
                Haptic.success()
            } catch { print("Update category error: \(error)") }
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name          = ""
    @State private var selectedIcon  = "tag.fill"
    @State private var selectedColor = "#6366F1"
    @State private var selectedType  = "expense"
    @State private var isSaving      = false

    private let icons: [String] = [
        "banknote.fill", "creditcard.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis",
        "percent", "building.columns.fill", "key.fill", "arrow.triangle.2.circlepath",
        "cart.fill", "bag.fill", "fork.knife", "cup.and.saucer.fill",
        "gift.fill", "tray.full.fill", "shippingbox.fill", "truck.box.fill",
        "car.fill", "airplane", "tram.fill", "bicycle",
        "heart.fill", "cross.case.fill", "figure.run", "shield.fill",
        "house.fill", "leaf.fill", "bolt.fill", "tv.fill",
        "laptopcomputer", "book.fill", "graduationcap.fill", "briefcase.fill",
        "gamecontroller.fill", "music.note", "film.fill", "headphones",
        "person.2.fill", "building.2.fill", "megaphone.fill", "wrench.and.screwdriver.fill",
        "tag.fill", "star.fill", "sparkles", "ellipsis.circle.fill", "pawprint.fill", "iphone"
    ]

    private let colors: [String] = [
        "#34D399", "#10B981", "#60A5FA", "#3B82F6", "#8B5CF6",
        "#6366F1", "#EC4899", "#F472B6", "#F59E0B", "#FB923C",
        "#EF4444", "#FB7185", "#06B6D4", "#2DD4BF", "#84CC16"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    previewCard
                    nameField
                    typeRow
                    colorSection
                    iconGrid
                }
                .padding(16).padding(.bottom, 32)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }.foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: {
                        if isSaving { ProgressView() }
                        else { Text(Localizer.shared.l("common.save")).bold() }
                    }
                    .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : AppTheme.baseColor)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var previewCard: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(hex: selectedColor).opacity(0.18))
                    .frame(width: 80, height: 80)
                Image(systemName: selectedIcon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color(hex: selectedColor))
            }
            Text(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Preview" : name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(name.isEmpty ? .secondary : .primary)
                .animation(.default, value: name)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            label(Localizer.shared.l("common.name"))
            TextField(Localizer.shared.l("category.namePlaceholder"), text: $name)
                .font(.system(size: 16)).padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var typeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            label(Localizer.shared.l("transaction.type"))
            HStack(spacing: 8) {
                typeChip("income",  Localizer.shared.l("transaction.income"),  "arrow.up.circle.fill", ZColor.income)
                typeChip("expense", Localizer.shared.l("transaction.expense"), "arrow.down.circle.fill",   ZColor.expense)
                typeChip("both",    NSLocalizedString("settings.both", comment: ""),    "arrow.up.arrow.down",    AppTheme.baseColor)
            }
        }
    }

    private func typeChip(_ val: String, _ lbl: String, _ icon: String, _ col: Color) -> some View {
        let sel = selectedType == val
        return Button { withAnimation(.spring(response: 0.25)) { selectedType = val }; Haptic.selection() } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(lbl).font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(sel ? col.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundColor(sel ? col : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(sel ? col.opacity(0.45) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(lbl) category type")
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label(Localizer.shared.l("common.color"))
            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(colors, id: \.self) { hex in
                    let sel = selectedColor == hex
                    Button { withAnimation(.spring(response: 0.2)) { selectedColor = hex }; Haptic.selection() } label: {
                        ZStack {
                            Circle().fill(Color(hex: hex))
                            if sel {
                                Circle().strokeBorder(.white, lineWidth: 2.5)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        .frame(height: 44)
                        .shadow(color: sel ? Color(hex: hex).opacity(0.5) : .clear, radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var iconGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            label(Localizer.shared.l("common.icon"))
            IconGridPicker(selectedIcon: $selectedIcon)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary).tracking(0.5)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let uid = authVM.currentUserId else { return }
        isSaving = true
        Task {
            _ = await transactionVM.addCategory(
                userId: uid, name: trimmed,
                color: selectedColor, icon: selectedIcon, type: selectedType)
            isSaving = false
            dismiss()
        }
    }
}


// MARK: - Export View

struct ExportView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var shareText: String? = nil
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.baseColor)
                    .padding(.top, 40)

                Text(Localizer.shared.l("export.title"))
                    .font(.system(size: 22, weight: .bold))

                Text(String(format: Localizer.shared.l("export.transactionsCount"), transactionVM.transactions.count))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    shareText = generateCSV()
                    showShare = true
                    Haptic.success()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                        Text(Localizer.shared.l("export.buttonCSV"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(AppTheme.accentGradient).foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("export.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.done", comment: "")) { dismiss() }.foregroundColor(AppTheme.baseColor)
                }
            }
            .sheet(isPresented: $showShare) {
                if let text = shareText {
                    ShareSheet(items: [text])
                }
            }
        }
    }

    private func generateCSV() -> String {
        var csv = "Date,Type,Amount,Currency,Category,Note\n"
        let sorted = transactionVM.transactions.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        for t in sorted {
            let date  = t.date?.formatted(.dateTime.year().month().day()) ?? ""
            let type  = t.type ?? ""
            let cat   = transactionVM.category(for: t.categoryId)?.name ?? ""
            let note  = t.note ?? ""
            csv += "\"\(date)\",\"\(type)\",\(t.amount),\(t.currency),\"\(cat)\",\"\(note)\"\n"
        }
        return csv
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
