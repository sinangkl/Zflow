import SwiftUI
import Supabase
import PostgREST

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @Environment(\.colorScheme) var scheme

    @AppStorage("defaultCurrency") private var defaultCurrency: String = "TRY"
    @AppStorage("appColorScheme")  private var appColorScheme: String  = "system"
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var showEditProfile    = false
    @State private var showBudgetManager  = false
    @State private var showCategoryMgr    = false
    @State private var showExport         = false
    @State private var showSignOutAlert   = false
    @State private var showBankConnection = false

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        profileCard
                        appearanceSection
                        preferencesSection
                        budgetSection
                        bankConnectionSection
                        if authVM.userProfile?.isBusiness == true {
                            VATPreviewCard()
                                .environmentObject(transactionVM)
                        }
                        dataSection
                        dangerSection
                        versionFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile)   { EditProfileView().environmentObject(authVM) }
            .sheet(isPresented: $showBudgetManager) {
                BudgetManagerView()
                    .environmentObject(transactionVM)
                    .environmentObject(budgetManager)
            }
            .sheet(isPresented: $showCategoryMgr) {
                CategoryManagerView()
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showExport) {
                ExportView().environmentObject(transactionVM)
            }
            .sheet(isPresented: $showBankConnection) {
                BankConnectionView().environmentObject(authVM)
            }
            .alert(NSLocalizedString("settings.signOut", comment: ""), isPresented: $showSignOutAlert) {
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("settings.signOut", comment: ""), role: .destructive) {
                    Task { await authVM.signOut() }
                }
            } message: {
                Text(NSLocalizedString("settings.signOutConfirm", comment: ""))
            }
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
                                    .foregroundColor(ZColor.indigo)
                            )
                            .offset(x: 26, y: 26)
                    }
                }

                VStack(spacing: 5) {
                    Text(authVM.userProfile?.displayName ?? "User")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Image(systemName: UserType(rawValue: authVM.userProfile?.userType ?? "personal")?.icon ?? "person.fill")
                            .font(.system(size: 11))
                        Text((authVM.userProfile?.userType ?? "personal").capitalized)
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
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        settingsSection(NSLocalizedString("settings.appearance", comment: "")) {
            settingsRow(icon: "moon.stars.fill", iconColor: ZColor.purple, title: NSLocalizedString("settings.theme", comment: "")) {
                Picker("", selection: $appColorScheme) {
                    Text(NSLocalizedString("settings.themeSystem", comment: "")).tag("system")
                    Text(NSLocalizedString("settings.themeLight", comment: "")).tag("light")
                    Text(NSLocalizedString("settings.themeDark", comment: "")).tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
        }
    }

    private var preferencesSection: some View {
        settingsSection(NSLocalizedString("settings.preferences", comment: "")) {
            VStack(spacing: 0) {
                settingsRow(icon: "dollarsign.circle.fill", iconColor: ZColor.income, title: NSLocalizedString("settings.defaultCurrency", comment: "")) {
                    Picker("", selection: $defaultCurrency) {
                        ForEach(Currency.allCases) { cur in
                            Text("\(cur.flag) \(cur.rawValue)").tag(cur.rawValue)
                        }
                    }
                    .tint(.primary)
                }
                divider
                settingsRow(icon: "lock.fill", iconColor: ZColor.indigo, title: NSLocalizedString("settings.staySignedIn", comment: "")) {
                    Toggle("", isOn: $authVM.rememberMe).labelsHidden()
                }
                divider
                settingsRow(icon: "globe", iconColor: Color(hex: "#8B5CF6"), title: NSLocalizedString("settings.language", comment: "")) {
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
                navRow(icon: "target", iconColor: Color(hex: "#F59E0B"),
                       title: NSLocalizedString("settings.manageBudgets", comment: ""),
                       badge: budgetManager.budgets.isEmpty ? nil : "\(budgetManager.budgets.count) active") {
                    showBudgetManager = true; Haptic.light()
                }
                divider
                navRow(icon: "tag.fill", iconColor: Color(hex: "#EC4899"),
                       title: NSLocalizedString("settings.manageCategories", comment: ""),
                       badge: "\(transactionVM.categories.count)") {
                    showCategoryMgr = true; Haptic.light()
                }
            }
        }
    }

    private var bankConnectionSection: some View {
        settingsSection(NSLocalizedString("bank.sectionTitle", comment: "")) {
            navRow(icon: "building.columns.fill", iconColor: Color(hex: "#059669"),
                   title: NSLocalizedString("bank.connectAccount", comment: ""),
                   badge: nil) {
                showBankConnection = true; Haptic.light()
            }
        }
    }

    private var dataSection: some View {
        settingsSection(NSLocalizedString("settings.exportData", comment: "")) {
            navRow(icon: "square.and.arrow.up.fill", iconColor: Color(hex: "#06B6D4"),
                   title: NSLocalizedString("settings.exportData", comment: ""), badge: nil) {
                showExport = true; Haptic.light()
            }
        }
    }

    private var dangerSection: some View {
        settingsSection(NSLocalizedString("settings.signOut", comment: "")) {
            Button {
                showSignOutAlert = true; Haptic.warning()
            } label: {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("ZFlow")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            Text("Version 1.0  •  Built with SwiftUI + Supabase")
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
    }
}

// MARK: - Edit Profile View (Madde 8: Profil fotoğrafı, PhotosUI)

import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    @State private var fullName       = ""
    @State private var businessName   = ""
    @State private var isSaving       = false
    @State private var photosItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showRemovePhotoAlert = false

    private var isBusiness: Bool { authVM.userProfile?.isBusiness == true }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Avatar picker section
                        avatarSection
                            .padding(.top, 16)

                        // Form fields
                        VStack(spacing: 0) {
                            formRow(icon: "person.fill", placeholder: NSLocalizedString("auth.fullName", comment: ""), text: $fullName)

                            if isBusiness {
                                Divider().padding(.leading, 50)
                                formRow(icon: "building.2.fill", placeholder: NSLocalizedString("auth.businessName", comment: ""), text: $businessName)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5)
                        )
                        .padding(.horizontal)

                        // Save button
                        Button {
                            isSaving = true
                            Task {
                                // Upload photo if changed
                                if let imgData = selectedImageData {
                                    await authVM.uploadAvatar(data: imgData)
                                }
                                let ok = await authVM.updateProfile(
                                    fullName: fullName,
                                    businessName: isBusiness ? businessName : nil)
                                isSaving = false
                                if ok { dismiss() }
                            }
                        } label: {
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
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(fullName.isEmpty || isSaving
                                          ? AnyShapeStyle(AppTheme.accentGradient.opacity(0.45))
                                          : AnyShapeStyle(AppTheme.accentGradient))
                            )
                            .shadow(color: ZColor.indigo.opacity(fullName.isEmpty ? 0 : 0.35), radius: 12, y: 4)
                        }
                        .disabled(fullName.isEmpty || isSaving)
                        .padding(.horizontal)

                        Spacer()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("settings.editProfile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                        .foregroundColor(ZColor.indigo)
                }
            }
            .onAppear {
                fullName     = authVM.userProfile?.fullName ?? ""
                businessName = authVM.userProfile?.businessName ?? ""
                selectedImageData = authVM.userAvatarData
            }
            .onChange(of: photosItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#5E5CE6").opacity(0.25), Color(hex: "#7D7AFF").opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 96, height: 96)

                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else {
                        Text(authVM.userProfile?.initials ?? "Z")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .overlay(Circle().strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 1.5))

                // Camera badge
                PhotosPicker(selection: $photosItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentGradient)
                            .frame(width: 30, height: 30)
                            .shadow(color: ZColor.indigo.opacity(0.4), radius: 6, y: 2)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            // Remove photo option
            if selectedImageData != nil {
                Button(NSLocalizedString("settings.removePhoto", comment: "")) {
                    selectedImageData = nil
                    photosItem = nil
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ZColor.expense)
            } else {
                PhotosPicker(selection: $photosItem, matching: .images) {
                    Text(NSLocalizedString("settings.addPhoto", comment: ""))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ZColor.indigo)
                }
            }
        }
    }

    private func formRow(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ZColor.indigo)
                .frame(width: 20)
                .padding(.leading, 16)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
        }
        .frame(minHeight: 52)
    }
}

// MARK: - Budget Manager View

struct BudgetManagerView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: Category?
    @State private var budgetText = ""

    private var expenseCategories: [Category] {
        transactionVM.categories.filter { cat in
            cat.type == "expense" || cat.type == "both" || cat.type == nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if expenseCategories.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "target")
                            .font(.system(size: 48))
                            .foregroundColor(ZColor.labelTert)
                        Text("No Categories Yet")
                            .font(.system(size: 18, weight: .bold))
                        Text("Add categories in Settings → Categories first, then come back to set budgets.")
                            .font(.system(size: 14))
                            .foregroundColor(ZColor.labelSec)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(expenseCategories) { cat in
                            let limit = budgetManager.budget(for: cat.id)
                            let spent = transactionVM.categorySpending(categoryId: cat.id)

                            VStack(spacing: 10) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(Color(hex: cat.color).opacity(0.15)).frame(width: 38, height: 38)
                                        Image(systemName: cat.icon ?? "circle").font(.system(size: 14)).foregroundColor(Color(hex: cat.color))
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(cat.name).font(.system(size: 14, weight: .semibold))
                                        if let l = limit {
                                            Text("\(spent.formattedCurrency(code: transactionVM.primaryCurrency)) / \(l.formattedCurrency(code: transactionVM.primaryCurrency))")
                                                .font(.system(size: 12)).foregroundColor(.secondary)
                                        } else {
                                            Text("No budget set").font(.system(size: 12)).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if let l = limit {
                                        let ratio = l > 0 ? spent / l : 0
                                        Circle()
                                            .fill(budgetManager.statusColor(ratio: ratio))
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                if let l = limit {
                                    BudgetProgressBar(spent: spent, limit: l,
                                                      color: Color(hex: cat.color), height: 6)
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCategory = cat
                                budgetText = limit.map { String(format: "%.0f", $0) } ?? ""
                                Haptic.selection()
                            }
                            .swipeActions(edge: .trailing) {
                                if limit != nil {
                                    Button(role: .destructive) {
                                        budgetManager.removeBudget(for: cat.id); Haptic.medium()
                                    } label: { Label("Remove", systemImage: "trash") }
                                }
                            }
                        }
                    } header: {
                        Text("Tap a category to set its monthly budget")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Category Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(ZColor.indigo)
                }
            }
            .alert("Set Budget", isPresented: Binding(
                get: { selectedCategory != nil },
                set: { if !$0 { selectedCategory = nil } }
            )) {
                TextField("Monthly limit", text: $budgetText).keyboardType(.decimalPad)
                Button("Save") {
                    if let cat = selectedCategory,
                       let val = Double(budgetText.replacingOccurrences(of: ",", with: ".")) {
                        budgetManager.setBudget(for: cat.id, limit: val); Haptic.success()
                    }
                    selectedCategory = nil
                }
                Button("Cancel", role: .cancel) { selectedCategory = nil }
            } message: {
                Text("Monthly limit for \(selectedCategory?.name ?? "")")
            }
        }
    }
}

// MARK: - Category Manager View

struct CategoryManagerView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showAdd     = false
    @State private var isRestoring = false

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
                                    Text(cat.name).font(.system(size: 14, weight: .semibold))
                                    Text((cat.type ?? "both").capitalized)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(typeColor(cat.type))
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Capsule().fill(typeColor(cat.type).opacity(0.12)))
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    if let uid = authVM.currentUserId {
                                        Task { await transactionVM.deleteCategory(
                                            id: cat.id, userId: uid,
                                            userType: authVM.userProfile?.userType ?? "personal") }
                                    }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundColor(ZColor.indigo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true; Haptic.light() } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(ZColor.indigo)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddCategorySheet()
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "tag.slash").font(.system(size: 52)).foregroundColor(ZColor.labelTert)
            Text("No Categories").font(.system(size: 20, weight: .bold))
            Text("Tap + to add custom categories,\nor restore built-in defaults.")
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
        default: return ZColor.indigo
        }
    }

    private func restoreDefaults() async {
        guard let uid = authVM.currentUserId else { return }
        let userType = authVM.userProfile?.userType ?? "personal"
        let inserts = filteredDefaultCategories(for: userType).map {
            CategoryInsert(userId: uid, name: $0.name, color: $0.color, icon: $0.icon, type: $0.type)
        }
        do {
            try await SupabaseManager.shared.client.from("categories").insert(inserts).execute()
            await transactionVM.fetchCategories(userId: uid, userType: userType)
        } catch { print("Restore error: \(error)") }
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
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(ZColor.indigo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: {
                        if isSaving { ProgressView() }
                        else { Text("Save").bold() }
                    }
                    .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : ZColor.indigo)
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
            label("Name")
            TextField("e.g. Groceries, Salary, Travel…", text: $name)
                .font(.system(size: 16)).padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var typeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Type")
            HStack(spacing: 8) {
                typeChip("income",  "Income",  "arrow.down.circle.fill", ZColor.income)
                typeChip("expense", "Expense", "arrow.up.circle.fill",   ZColor.expense)
                typeChip("both",    "Both",    "arrow.up.arrow.down",    ZColor.indigo)
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
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Color")
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
            label("Icon")
            let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    let sel = selectedIcon == icon
                    Button { withAnimation(.spring(response: 0.2)) { selectedIcon = icon }; Haptic.selection() } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(sel ? Color(hex: selectedColor).opacity(0.18)
                                          : Color(.secondarySystemGroupedBackground))
                                .frame(height: 46)
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(sel ? Color(hex: selectedColor).opacity(0.55) : .clear, lineWidth: 1.5))
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(sel ? Color(hex: selectedColor) : ZColor.labelSec)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
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
                    .foregroundColor(ZColor.indigo)
                    .padding(.top, 40)

                Text("Export Transactions")
                    .font(.system(size: 22, weight: .bold))

                Text("Export your \(transactionVM.transactions.count) transactions as a CSV file to use in Excel or Google Sheets.")
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
                        Text("Export as CSV")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(AppTheme.accentGradient).foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundColor(ZColor.indigo)
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
