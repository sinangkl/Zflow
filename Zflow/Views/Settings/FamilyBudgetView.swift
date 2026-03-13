// ============================================================
// ZFlow — Family Budget View
// Apple Family-style shared budgets with Supabase RLS
// ============================================================

import SwiftUI

// MARK: - Family Group Model

struct FamilyBudgetView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var familyVM: FamilyViewModel
    @EnvironmentObject var activityVM: FamilyActivityViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var goalVM: GoalViewModel
    @Environment(\.colorScheme) var scheme
    
    // Deep link invitation support
    var deepLinkFamilyID: String? = nil
    @State private var showingJoinAlert = false
    @State private var invitationID: String? = nil

    @State private var inviteEmail = ""
    @State private var newFamilyName = ""
    @State private var showingInviteSheet = false
    @State private var showingCreateSheet = false
    
    // Member management
    @State private var showingMemberSettings = false
    @State private var selectedMember: FamilyMember? = nil
    @State private var editRole = "member"
    @State private var editRelationship = ""

    // Budget management
    @State private var showingAddBudgetSheet = false
    @State private var selectedCategoryForBudget: Category?
    @State private var budgetLimitInput = ""

    // New: Invite link, rename, leave confirmation, remove member
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showLeaveAlert = false
    @State private var showRemoveMemberAlert = false
    @State private var showRenameSheet = false
    @State private var renameFamilyInput = ""
    @State private var showAllActivities = false
    @State private var showQRSheet = false
    @State private var showScannerSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero
                        heroCard
                        
                        if familyVM.isLoading {
                            ProgressView().padding(40)
                        } else if familyVM.family == nil {
                            noFamilyState
                        } else {
                            // Pending Requests (only for admins)
                            if familyVM.members.first(where: { $0.userId == authVM.currentUserId })?.role == "admin" {
                                pendingRequestsSection
                            }
                            
                            // Activity Feed (Aile Akışı)
                            activityFeedSection
                            
                            // Members list
                            membersSection
                            
                            // Shared Goals
                            familyGoalsSection
                            
                            // Shared budgets
                            sharedBudgetsSection
                            
                            // Invite button
                            inviteButton
                            
                            // Leave button
                            leaveButton
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 85)
                }
                .refreshable {
                    if let uid = authVM.currentUserId {
                        await familyVM.fetchFamilyInfo(userId: uid)
                        if let fid = familyVM.family?.id {
                            await activityVM.fetchActivities(familyId: fid)
                            await goalVM.fetchGoals(userId: uid, familyId: fid)
                        }
                    }
                }
            }
            .navigationTitle("Aile Bütçesi")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingInviteSheet) {
                inviteSheet
            }
            .sheet(isPresented: $showingCreateSheet) {
                createFamilySheet
            }
            .sheet(isPresented: $showingMemberSettings) {
                memberSettingsSheet
            }
            .sheet(isPresented: $showingAddBudgetSheet) {
                addBudgetSheet
            }
            .sheet(isPresented: $showRenameSheet) {
                renameFamilySheet
            }
            .sheet(isPresented: $showAllActivities) {
                allActivitiesSheet
            }
            .sheet(isPresented: $showQRSheet) {
                if let family = familyVM.family {
                    let inviteLink = "zflow://family/invite?id=\(family.id.uuidString)"
                    FamilyInviteQRView(inviteURL: inviteLink, themeColorHex: family.cardColor ?? "#FF6B6B", familyName: family.name)
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showScannerSheet) {
                // Placeholder for QR Scanner View. Requires iOS 16 DataScannerViewController or AVFoundation implementation.
                FamilyScannerView()
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { shareURL = nil }) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .onAppear {
            if let uid = authVM.currentUserId {
                Task { await familyVM.fetchFamilyInfo(userId: uid) }
            }
            
            // Check for deep link invitation
            if let id = deepLinkFamilyID {
                invitationID = id
                showingJoinAlert = true
            }
        }
        .alert("Aile Grubuna Katıl", isPresented: $showingJoinAlert) {
            Button("İptal", role: .cancel) { invitationID = nil }
            Button("Katıl") {
                if let id = invitationID, let uid = authVM.currentUserId {
                    Task { await familyVM.joinFamily(familyId: id, userId: uid) }
                }
            }
        } message: {
            Text("Bu aile grubuna katılmak ve bütçenizi ortak yönetmek istiyor musunuz?")
        }
        .alert("Aileden Ayrıl", isPresented: $showLeaveAlert) {
            Button("İptal", role: .cancel) {}
            Button("Ayrıl", role: .destructive) {
                if let uid = authVM.currentUserId {
                    Task { await familyVM.leaveFamily(userId: uid) }
                }
            }
        } message: {
            Text("Aile grubundan ayrılmak istediğinizden emin misiniz? Bu işlem geri alınamaz.")
        }
        .alert("Üyeyi Çıkar", isPresented: $showRemoveMemberAlert) {
            Button("İptal", role: .cancel) {}
            Button("Çıkar", role: .destructive) {
                if let member = selectedMember, let aid = authVM.currentUserId {
                    Task {
                        await familyVM.removeMember(memberId: member.userId, adminId: aid)
                        showingMemberSettings = false
                    }
                }
            }
        } message: {
            Text("\(selectedMember?.displayName ?? "Bu üye") aile grubundan çıkarılacak. Emin misiniz?")
        }
    }

    // MARK: - No Family State

    // MARK: - No Family State
    private var noFamilyState: some View {
        VStack(spacing: 20) {
            EmptyStateView(
                icon: "person.3.sequence.fill",
                title: "Aile Bütçesi",
                message: "Harcamalarınızı sevdiklerinizle ortak takip etmek için hemen bir aile grubu oluşturun.",
                actionLabel: "Aile Grubu Oluştur",
                action: { showingCreateSheet = true }
            )
            .liquidGlass(cornerRadius: 24)
            .padding(.top, 20)
        }
    }

    // MARK: - Activity Feed

    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "AİLE AKIŞI",
                trailing: activityVM.activities.count > 5 ? "Tümünü Gör" : nil,
                trailingAction: { showAllActivities = true }
            )

            if activityVM.activities.isEmpty {
                EmptyStateView(
                    icon: "bell.slash.fill",
                    title: "Aktivite Yok",
                    message: "Ailenizdeki harcama ve işlemler burada görünecektir."
                )
                .liquidGlass(cornerRadius: 20)
            } else {
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 0) {
                        ForEach(activityVM.activities.prefix(5)) { activity in
                            HStack(spacing: 16) {
                                // Icon with frosted background
                                ZStack {
                                    Circle()
                                        .fill(activityColor(for: activity.actionType).opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: activityIcon(for: activity.actionType))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(activityColor(for: activity.actionType))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(activityDescription(for: activity))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ZColor.label)
                                        .lineLimit(2)
                                    Text(activity.createdAt, style: .relative)
                                        .font(.system(size: 13))
                                        .foregroundColor(ZColor.labelSec)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            if activity.id != activityVM.activities.prefix(5).last?.id {
                                Divider()
                                    .background(Color.secondary.opacity(0.2))
                                    .padding(.leading, 76)
                            }
                        }
                    }
                }
            }
        }
    }

    private func activityIcon(for type: String) -> String {
        switch type {
        case "expense_added": return "cart.fill"
        case "goal_completed": return "trophy.fill"
        case "member_joined": return "person.badge.plus.fill"
        default: return "star.fill"
        }
    }

    private func activityColor(for type: String) -> Color {
        switch type {
        case "expense_added": return .red
        case "goal_completed": return ZColor.amber
        case "member_joined": return .blue
        default: return .primary
        }
    }

    private func activityDescription(for activity: FamilyActivity) -> String {
        // Find member name
        let name = familyVM.members.first { $0.userId == activity.userId }?.displayName ?? "Bir üye"
        switch activity.actionType {
        case "expense_added":
            return "\(name) yeni bir harcama ekledi."
        case "goal_completed":
            return "\(name) bir hedefi tamamladı! 🎉"
        case "member_joined":
            return "\(name) aileye katıldı."
        default:
            return "\(name) bir işlem yaptı."
        }
    }

    // MARK: - Family Goals

    private var familyGoalsSection: some View {
        let familyGoals = goalVM.goals.filter { $0.familyId != nil }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ORTAK HEDEFLER")

            if familyGoals.isEmpty {
                EmptyStateView(
                    icon: "target",
                    title: "Hedef Yok",
                    message: "Aileniz için bir birikim hedefi belirleyin."
                )
                .liquidGlass(cornerRadius: 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(familyGoals) { goal in
                        GlassCard(cornerRadius: 20) {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: goal.colorHex).opacity(0.12))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: goal.icon)
                                            .foregroundColor(Color(hex: goal.colorHex))
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(goal.title)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(ZColor.label)
                                        Text("\(goal.currentAmount.formattedShort()) / \(goal.targetAmount.formattedShort())")
                                            .font(.system(size: 12))
                                            .foregroundColor(ZColor.labelSec)
                                    }
                                    Spacer()
                                    Text("\(Int(goal.percentage))%")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(Color(hex: goal.colorHex))
                                }
                                
                                BudgetProgressBar(spent: goal.currentAmount, limit: goal.targetAmount, color: Color(hex: goal.colorHex), height: 8)
                            }
                            .padding(16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let cardColor = Color(hex: familyVM.family?.cardColor ?? "#FF6B6B")
        let gradient = LinearGradient(colors: [cardColor, cardColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        let isAdmin = familyVM.members.first(where: { $0.userId == authVM.currentUserId })?.role == "admin"
        
        return GradientCard(gradient: gradient, cornerRadius: 28) {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    // Left Side: Icon & Title
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                        Text(familyVM.family?.name ?? "Aile Bütçesi")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Spacer()
                    
                    // Right Side: Edit Button
                    if isAdmin {
                        Button {
                            renameFamilyInput = familyVM.family?.name ?? ""
                            showRenameSheet = true
                            Haptic.light()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(cardColor)
                                .padding(10)
                                .background(Circle().fill(.white))
                        }
                    }
                }
                
                // Stats Grid
                HStack(spacing: 0) {
                    heroStatItem(
                        value: "\(familyVM.members.filter { $0.status == "active" }.count)",
                        title: "Üye",
                        icon: "person.2.fill"
                    )
                    Divider().background(.white.opacity(0.3)).frame(height: 40)
                    heroStatItem(
                        value: "\(familyVM.members.filter { $0.status == "pending" }.count)",
                        title: "Bekleyen",
                        icon: "person.crop.circle.badge.clock"
                    )
                    Divider().background(.white.opacity(0.3)).frame(height: 40)
                    heroStatItem(
                        value: "\(budgetManager.budgets.count)",
                        title: "Bütçe",
                        icon: "chart.pie.fill"
                    )
                }
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).opacity(0.2))
                
                if isAdmin {
                    HStack(spacing: 12) {
                        Button {
                            showQRSheet = true
                            Haptic.selection()
                        } label: {
                            HStack {
                                Image(systemName: "qrcode")
                                Text("QR Kod")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(cardColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(.white))
                        }

                        Button {
                            if let fid = familyVM.family?.id {
                                shareURL = URL(string: "zflow://family/invite?id=\(fid.uuidString)")
                                showShareSheet = true
                                Haptic.selection()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Davet Linki")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(cardColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(.white))
                        }
                        
                        Button {
                            showScannerSheet = true
                            Haptic.selection()
                        } label: {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                Text("Okut")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(cardColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(.white))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(24)
        }
    }
    
    private func heroStatItem(value: String, title: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ÜYE LİSTESİ")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if familyVM.members.isEmpty {
                        EmptyStateView(
                            icon: "person.2.slash",
                            title: "Üye Yok",
                            message: "Ailenize henüz üye katılmamış."
                        )
                        .liquidGlass(cornerRadius: 20)
                        .frame(width: 250)
                    } else {
                        ForEach(familyVM.members.filter { $0.status == "active" }) { member in
                            Button {
                                let isAdmin = familyVM.members.first(where: { $0.userId == authVM.currentUserId })?.role == "admin"
                                if isAdmin && member.userId != authVM.currentUserId {
                                    selectedMember = member
                                    editRole = member.role
                                    editRelationship = member.relationship ?? ""
                                    showingMemberSettings = true
                                    Haptic.light()
                                }
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Circle()
                                            .fill(LinearGradient(colors: [AppTheme.baseColor.opacity(0.8), AppTheme.baseColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 64, height: 64)
                                            .shadow(color: AppTheme.baseColor.opacity(0.3), radius: 8, y: 4)
                                            .overlay(
                                                Text(String((member.displayName ?? "U").prefix(1)))
                                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                            )
                                        
                                        if member.role == "admin" {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .padding(4)
                                                .background(Circle().fill(ZColor.amber))
                                                .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                                                .offset(x: 2, y: 2)
                                        }
                                    }
                                    
                                    VStack(spacing: 2) {
                                        Text(member.displayName ?? "İsimsiz")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(ZColor.label)
                                            .lineLimit(1)
                                        
                                        if let rel = member.relationship, !rel.isEmpty {
                                            Text(rel)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(ZColor.labelSec)
                                        } else {
                                            Text(member.role == "admin" ? "Yönetici" : "Üye")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(ZColor.labelTert)
                                        }
                                    }
                                }
                                .frame(width: 100)
                                .padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                            }
                            .buttonStyle(FABButtonStyle())
                        }
                    }
                    
                    // Add Member Button (Admin only)
                    if familyVM.members.first(where: { $0.userId == authVM.currentUserId })?.role == "admin" {
                        Button {
                            showingInviteSheet = true
                            Haptic.light()
                        } label: {
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(AppTheme.baseColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(AppTheme.baseColor)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("Yeni Üye")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppTheme.baseColor)
                                    Text("Davet Et")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.baseColor.opacity(0.7))
                                }
                            }
                            .frame(width: 100)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 20).fill(AppTheme.baseColor.opacity(0.05)))
                        }
                        .buttonStyle(FABButtonStyle())
                        .padding(.trailing, 4) // extra padding at end of scroll view
                    }
                }
                .padding(.horizontal, 4) // small padding so shadows aren't clipped
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -16) // full bleed scroll view
            .padding(.leading, 16) // restore inset
        }
    }
    
    // MARK: - Pending Transactions Section (Admins Only)
    
    @ViewBuilder
    private var pendingTransactionsSection: some View {
        let isAdmin = familyVM.members.first(where: { $0.userId == authVM.currentUserId })?.role == "admin"
        if isAdmin {
            let pendingTxns = transactionVM.transactions.filter { $0.status == "pending" }
            if !pendingTxns.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "BEKLEYEN İŞLEMLER (\(pendingTxns.count))")
                    
                    VStack(spacing: 12) {
                        ForEach(pendingTxns) { txn in
                            pendingTransactionCard(txn)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func pendingTransactionCard(_ txn: Transaction) -> some View {
        let isIncome = txn.type == "income"
        let color = isIncome ? ZColor.income : ZColor.expense
        let cat = transactionVM.category(for: txn.categoryId)
        let amountStr = txn.amount.formattedCurrency(code: txn.currency)
        let member = familyVM.members.first(where: { $0.userId == txn.userId })
        
        return GlassCard(cornerRadius: 16) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: cat?.color ?? "#9CA3AF").opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: cat?.icon ?? "tag.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: cat?.color ?? "#9CA3AF"))
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cat?.name ?? "Kategori Yok")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ZColor.label)
                        
                        Text("\(member?.displayName ?? "Üye") • \(txn.date?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ZColor.labelSec)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Amount & Badge
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(isIncome ? "+" : "-")\(amountStr)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                        
                        if txn.attachmentURL != nil {
                            Image(systemName: "paperclip")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.baseColor)
                        }
                    }
                }
                
                if let note = txn.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundColor(ZColor.labelSec)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, -4)
                }
                
                Divider()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        updateTransactionStatus(txn, newStatus: "rejected")
                    } label: {
                        Text("Reddet")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(ZColor.expense))
                    }
                    
                    Button {
                        updateTransactionStatus(txn, newStatus: "approved")
                    } label: {
                        Text("Onayla")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.baseColor))
                    }
                }
            }
            .padding(16)
        }
    }
    
    private func updateTransactionStatus(_ txn: Transaction, newStatus: String) {
        guard let uid = authVM.currentUserId else { return }
        Task {
            // Need to create a specific update for just status in the viewModel
            // For now, using full update:
            await transactionVM.updateTransaction(
                id: txn.id, 
                userId: txn.userId ?? uid, 
                amount: txn.amount, 
                currency: Currency(rawValue: txn.currency) ?? .try_, 
                type: TransactionType(rawValue: txn.type ?? "expense") ?? .expense, 
                categoryId: txn.categoryId, 
                note: txn.note, 
                date: txn.date ?? Date(),
                status: newStatus,
                attachmentURL: txn.attachmentURL
            )
        }
    }

    private var pendingRequestsSection: some View {
        let pending = familyVM.members.filter { $0.status == "pending" }
        return Group {
            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "ONAY BEKLEYEN İSTEKLER")

                    VStack(spacing: 12) {
                        ForEach(pending) { member in
                            GlassCard(cornerRadius: 20) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "person.badge.clock.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.displayName ?? "Yeni Üye")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(ZColor.label)
                                        Text("Katılmak istiyor")
                                            .font(.system(size: 13))
                                            .foregroundColor(ZColor.labelSec)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 12) {
                                        Button {
                                            if let aid = authVM.currentUserId {
                                                Task {
                                                    await familyVM.rejectMember(memberId: member.userId, adminId: aid)
                                                    Haptic.warning()
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.red)
                                                .padding(10)
                                                .background(Circle().fill(.red.opacity(0.1)))
                                        }
                                        
                                        Button {
                                            if let aid = authVM.currentUserId {
                                                Task {
                                                    await familyVM.approveMember(memberId: member.userId, adminId: aid)
                                                    Haptic.success()
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.green)
                                                .padding(10)
                                                .background(Circle().fill(.green.opacity(0.1)))
                                        }
                                    }
                                }
                                .padding(16)
                            }
                        }
                    }
                }
            }
        }
    }

    private var memberSettingsSheet: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                
                VStack(spacing: 25) {
                    if let member = selectedMember {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [AppTheme.baseColor.opacity(0.8), AppTheme.baseColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: AppTheme.baseColor.opacity(0.3), radius: 12, y: 6)
                                
                                Text(String((member.displayName ?? "U").prefix(1)))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 4) {
                                Text(member.displayName ?? "Üye")
                                    .font(.system(size: 18, weight: .bold))
                                Text(member.role == "admin" ? "Yönetici" : "Aile Üyesi")
                                    .font(.system(size: 14))
                                    .foregroundColor(ZColor.labelSec)
                            }
                        }
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("YAKINLIK DERECESİ")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                                
                                TextField("Örn: Eşim, Oğlum, Kızım...", text: $editRelationship)
                                    .padding(16)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("YETKİ")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                                
                                Picker("Yetki", selection: $editRole) {
                                    Text("Üye").tag("member")
                                    Text("Yönetici").tag("admin")
                                }
                                .pickerStyle(.segmented)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
                            }
                        }
                        .padding(.horizontal)

                        Spacer()

                        VStack(spacing: 12) {
                            Button {
                                if let member = selectedMember, let aid = authVM.currentUserId {
                                    Task {
                                        await familyVM.updateMemberSettings(
                                            memberId: member.userId,
                                            adminId: aid,
                                            role: editRole,
                                            relationship: editRelationship
                                        )
                                        showingMemberSettings = false
                                        Haptic.success()
                                    }
                                }
                            } label: {
                                Text("Kaydet")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.baseColor))
                                    .shadow(color: AppTheme.baseColor.opacity(0.2), radius: 8, y: 4)
                            }

                            Button {
                                showRemoveMemberAlert = true
                            } label: {
                                Text("Üyeyi Çıkar")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3), lineWidth: 1))
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Üye Ayarları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { showingMemberSettings = false }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
        }
        .presentationDetents([.height(550)])
    }


    // MARK: - Shared Budgets

    private var sharedBudgetsSection: some View {
        let isAdmin = familyVM.members.first(where: { $0.userId == authVM.currentUserId })?.role == "admin"

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "ORTAK BÜTÇELER",
                trailing: isAdmin ? "Ekle" : nil,
                trailingAction: {
                    showingAddBudgetSheet = true
                    Haptic.light()
                }
            )

            GlassCard(cornerRadius: 20) {
                VStack(spacing: 0) {
                    if budgetManager.budgets.isEmpty {
                        EmptyStateView(
                            icon: "chart.pie.fill",
                            title: "Bütçe Verisi Yok",
                            message: isAdmin ? "Aile bütçesi oluşturmak için 'Ekle' butonuna dokunun." : "Henüz ortak bir bütçe oluşturulmamış."
                        )
                    } else {
                        ForEach(Array(transactionVM.categories.enumerated()), id: \.element.id) { idx, category in
                            if let limit = budgetManager.budgets[category.id] {
                                let spent = transactionVM.transactions
                                    .filter { $0.categoryId == category.id }
                                    .reduce(0) { $0 + abs($1.amount) }
                                let catColor = Color(hex: category.color)

                                VStack(spacing: 12) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(catColor.opacity(0.12))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: category.icon ?? "circle")
                                                .foregroundColor(catColor)
                                                .font(.system(size: 16, weight: .semibold))
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(category.localizedName)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(ZColor.label)
                                            Text("\(spent.formattedShort()) / \(limit.formattedShort())")
                                                .font(.system(size: 12))
                                                .foregroundColor(ZColor.labelSec)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            let ratio = limit > 0 ? spent/limit : 0
                                            Text("\(Int(min(ratio, 1.0) * 100))%")
                                                .font(.system(size: 14, weight: .black, design: .rounded))
                                                .foregroundColor(budgetManager.statusColor(ratio: ratio))
                                        }
                                    }

                                    BudgetProgressBar(spent: spent, limit: limit, color: catColor, height: 8)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)

                                if idx < transactionVM.categories.count - 1 {
                                    Divider()
                                        .background(Color.secondary.opacity(0.2))
                                        .padding(.leading, 70)
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    // MARK: - Invite Button

    private var inviteButton: some View {
        Button {
            showingInviteSheet = true
        } label: {
            Label("Aile Üyesi Davet Et", systemImage: "person.badge.plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 16).fill(
                    LinearGradient(colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF9F0A")],
                                   startPoint: .leading, endPoint: .trailing)
                ))
        }
        .buttonStyle(.plain)
    }

    private var leaveButton: some View {
        Button {
            showLeaveAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Aileden Ayrıl")
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3), lineWidth: 1))
        }
        .padding(.top, 10)
    }

    // MARK: - Create Family Sheet

    private var createFamilySheet: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                
                VStack(spacing: 25) {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.baseColor)
                            .versionedSymbolEffect(.bounce)
                        
                        Text("Aileyi Kurun")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                    }
                    .padding(.top, 30)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("AİLE GRUBU ADI")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        TextField("Örn: Yılmaz Ailesi", text: $newFamilyName)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                    }
                    .padding(.horizontal)
                    
                    Button {
                        if let uid = authVM.currentUserId {
                            Task {
                                await familyVM.createFamily(name: newFamilyName, adminId: uid)
                                showingCreateSheet = false
                                Haptic.success()
                            }
                        }
                    } label: {
                        Text("Oluştur")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 16).fill(
                                newFamilyName.isEmpty ? AnyShapeStyle(Color.secondary.opacity(0.5)) : AnyShapeStyle(AppTheme.baseColor)
                            ))
                            .shadow(color: AppTheme.baseColor.opacity(newFamilyName.isEmpty ? 0 : 0.2), radius: 8, y: 4)
                    }
                    .disabled(newFamilyName.isEmpty)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Yeni Aile Grubu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { showingCreateSheet = false }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
        }
        .presentationDetents([.height(400)])
    }

    // MARK: - Invite Sheet

    private var inviteSheet: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                
                VStack(spacing: 25) {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF9F0A")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .versionedSymbolEffect(.pulse)
                            .padding(.top, 20)
                        
                        Text("Aile Üyesi Daveti")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                        
                        Text("Aile üyesinin e-posta adresini girin. Davetiyeyi kabul ettiklerinde bütçenize dahil olurlar.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("E-POSTA ADRESİ")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        TextField("E-posta adresi", text: $inviteEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                    }
                    .padding(.horizontal)

                    Button {
                        sendInvite()
                    } label: {
                        Text("Davet Gönder")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 16).fill(
                                LinearGradient(colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF9F0A")],
                                               startPoint: .leading, endPoint: .trailing)
                            ))
                            .shadow(color: Color(hex: "#FF6B6B").opacity(inviteEmail.isEmpty ? 0 : 0.2), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(inviteEmail.isEmpty || !inviteEmail.contains("@"))
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Üye Davet Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { showingInviteSheet = false }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
        }
        .presentationDetents([.height(500)])
    }

    private func sendInvite() {
        guard !inviteEmail.isEmpty, let uid = authVM.currentUserId else { return }
        Task {
            let success = await familyVM.sendInvite(email: inviteEmail, inviterId: uid)
            if success {
                showingInviteSheet = false
                inviteEmail = ""
            }
        }
    }

    // MARK: - Add Budget Sheet

    private var addBudgetSheet: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("KATEGORİ SEÇİN")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(transactionVM.categories) { cat in
                                        let isSelected = selectedCategoryForBudget?.id == cat.id
                                        Button {
                                            selectedCategoryForBudget = cat
                                            Haptic.selection()
                                        } label: {
                                            VStack(spacing: 8) {
                                                ZStack {
                                                    Circle()
                                                        .fill(isSelected ? Color(hex: cat.color) : Color(.secondarySystemGroupedBackground))
                                                        .frame(width: 44, height: 44)
                                                    Image(systemName: cat.icon ?? "circle")
                                                        .foregroundColor(isSelected ? .white : Color(hex: cat.color))
                                                        .font(.system(size: 18, weight: .bold))
                                                }
                                                Text(cat.localizedName)
                                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                                    .foregroundColor(isSelected ? ZColor.label : ZColor.labelSec)
                                            }
                                            .frame(width: 80)
                                            .padding(.vertical, 12)
                                            .background(RoundedRectangle(cornerRadius: 16).fill(isSelected ? Color(hex: cat.color).opacity(0.1) : Color.clear))
                                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color(hex: cat.color) : Color.clear, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LİMİT BELİRLEYİN")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            HStack {
                                Text(transactionVM.primaryCurrency)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.secondary)
                                TextField("Aylık Limit", text: $budgetLimitInput)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button {
                        saveFamilyBudget()
                    } label: {
                        Text("Bütçe Oluştur")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 16).fill(
                                (selectedCategoryForBudget == nil || budgetLimitInput.isEmpty) ? AnyShapeStyle(Color.secondary.opacity(0.5)) : AnyShapeStyle(AppTheme.baseColor)
                            ))
                            .shadow(color: AppTheme.baseColor.opacity(budgetLimitInput.isEmpty ? 0 : 0.2), radius: 8, y: 4)
                    }
                    .disabled(selectedCategoryForBudget == nil || budgetLimitInput.isEmpty)
                    .padding(20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Yeni Ortak Bütçe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { showingAddBudgetSheet = false }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
        }
        .presentationDetents([.height(550)])
    }

    private func saveFamilyBudget() {
        guard let familyId = familyVM.family?.id,
              let category = selectedCategoryForBudget,
              let limit = Double(budgetLimitInput.replacingOccurrences(of: ",", with: ".")) else {
            return
        }

        budgetManager.setFamilyBudget(
            familyId: familyId,
            categoryId: category.id,
            limit: limit,
            currency: transactionVM.primaryCurrency
        )

        Haptic.success()
        showingAddBudgetSheet = false
        budgetLimitInput = ""
        selectedCategoryForBudget = nil
    }

    // MARK: - Rename Family Sheet

    private var renameFamilySheet: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("YENİ AİLE ADI")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        TextField("Aile Grubu Adı", text: $renameFamilyInput)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                    }
                    .padding(.horizontal)

                    Button {
                        if let fid = familyVM.family?.id, let aid = authVM.currentUserId,
                           !renameFamilyInput.trimmingCharacters(in: .whitespaces).isEmpty {
                            Task {
                                await familyVM.renameFamilyName(familyId: fid, adminId: aid,
                                                                newName: renameFamilyInput.trimmingCharacters(in: .whitespaces))
                                showRenameSheet = false
                                Haptic.success()
                            }
                        }
                    } label: {
                        Text("Kaydet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 16).fill(
                                renameFamilyInput.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AnyShapeStyle(Color.secondary.opacity(0.5))
                                    : AnyShapeStyle(AppTheme.baseColor)
                            ))
                    }
                    .disabled(renameFamilyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 30)
            }
            .navigationTitle("Aile Adını Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { showRenameSheet = false }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
        }
        .presentationDetents([.height(350)])
    }

    // MARK: - All Activities Sheet

    private var allActivitiesSheet: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(activityVM.activities) { activity in
                            HStack(spacing: 12) {
                                Image(systemName: activityIcon(for: activity.actionType))
                                    .foregroundColor(activityColor(for: activity.actionType))
                                    .frame(width: 36, height: 36)
                                    .background(activityColor(for: activity.actionType).opacity(0.1))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(activityDescription(for: activity))
                                        .font(.system(size: 13, weight: .medium))
                                    Text(activity.createdAt, style: .relative)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            Divider().padding(.leading, 64)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Tüm Aktiviteler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { showAllActivities = false }
                        .foregroundColor(AppTheme.baseColor)
                }
            }
        }
    }
}

