import SwiftUI

struct BulkImportVerificationView: View {
    @ObservedObject var viewModel: BulkImportViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @Binding var transactions: [StatementTransaction]
    @State private var selectedIds: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var editingTransaction: StatementTransaction?
    @State private var showExitConfirm = false

    private var selectedCount: Int { selectedIds.count }
    private var allSelected: Bool { selectedIds.count == transactions.count && !transactions.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

                List {
                    ForEach($transactions) { $txn in
                        transactionRow(txn: $txn)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        selectedIds.remove(txn.id)
                                        transactions.removeAll { $0.id == txn.id }
                                    }
                                    Haptic.medium()
                                } label: {
                                    Label(NSLocalizedString("common.delete", comment: "Sil"), systemImage: "trash.fill")
                                }

                                Button {
                                    editingTransaction = txn
                                    Haptic.light()
                                } label: {
                                    Label(NSLocalizedString("common.edit", comment: "Düzenle"), systemImage: "pencil")
                                }
                                .tint(AppTheme.baseColor)
                            }
                            .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    Color.clear.frame(height: 110)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // Fixed bottom overlay
                VStack {
                    Spacer()
                    footer
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(
                Text(String(format: NSLocalizedString("bulk.countSub", comment: "%d işlem bulundu."), transactions.count))
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingToolbarContent
                }
                ToolbarItem(placement: .topBarTrailing) {
                    trailingToolbarContent
                }
            }
        }
        .interactiveDismissDisabled(true)
        .sheet(item: $editingTransaction) { txn in
            BulkTransactionEditSheet(
                transaction: txn,
                categories: transactionVM.categories
            ) { updated in
                if let idx = transactions.firstIndex(where: { $0.id == updated.id }) {
                    transactions[idx] = updated
                }
            }
            .presentationDetents([.large])
            .presentationBackground(.ultraThinMaterial)
        }
        .confirmationDialog(
            "Çıkmak istediğinizden emin misiniz?",
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button("Çık", role: .destructive) { dismiss() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Kaydedilmemiş değişiklikler kaybolacak.")
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var leadingToolbarContent: some View {
        if isSelectionMode && selectedCount > 0 {
            // Action Menu — appears when items are selected
            Menu {
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.3)) {
                        transactions.removeAll { selectedIds.contains($0.id) }
                        selectedIds.removeAll()
                        if transactions.isEmpty { isSelectionMode = false }
                    }
                    Haptic.medium()
                } label: {
                    Label(
                        String(format: NSLocalizedString("bulk.deleteSelected", comment: "%d Seçiliyi Sil"), selectedCount),
                        systemImage: "trash"
                    )
                }

                Divider()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if allSelected { selectedIds.removeAll() }
                        else { selectedIds = Set(transactions.map { $0.id }) }
                    }
                    Haptic.selection()
                } label: {
                    Label(
                        allSelected ? "Seçimi Kaldır" : "Tümünü Seç",
                        systemImage: allSelected ? "circle" : "checkmark.circle"
                    )
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.baseColor)
                        .symbolRenderingMode(.hierarchical)

                    // Selection count badge
                    Text("\(selectedCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(AppTheme.baseColor, in: Capsule())
                        .offset(x: 6, y: -4)
                }
            }
        } else {
            // X close button
            Button {
                showExitConfirm = true
                Haptic.light()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var trailingToolbarContent: some View {
        if isSelectionMode {
            HStack(spacing: 14) {
                if selectedCount > 0 {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            if allSelected { selectedIds.removeAll() }
                            else { selectedIds = Set(transactions.map { $0.id }) }
                        }
                        Haptic.selection()
                    } label: {
                        Text(allSelected ? "Kaldır" : "Tümü")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.baseColor)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.spring(response: 0.35)) {
                        isSelectionMode = false
                        selectedIds.removeAll()
                    }
                    Haptic.light()
                } label: {
                    Text(NSLocalizedString("common.cancel", comment: "İptal"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                withAnimation(.spring(response: 0.35)) {
                    isSelectionMode = true
                    selectedIds = Set(transactions.map { $0.id })
                }
                Haptic.light()
            } label: {
                Text(NSLocalizedString("common.select", comment: "Seç"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.baseColor)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Row

    private func transactionRow(txn: Binding<StatementTransaction>) -> some View {
        let t = txn.wrappedValue
        let cat = transactionVM.categories.first(where: { $0.id.uuidString == t.category_id })
        let color = cat.map { Color(hex: $0.color) } ?? Color.orange
        let isSelected = selectedIds.contains(t.id)

        return Button {
            if isSelectionMode {
                withAnimation(.spring(response: 0.25)) {
                    if isSelected { selectedIds.remove(t.id) }
                    else { selectedIds.insert(t.id) }
                }
                Haptic.selection()
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox — only in selection mode
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? AppTheme.baseColor : Color.secondary.opacity(0.4))
                        .symbolRenderingMode(.hierarchical)
                        .transition(.scale.combined(with: .opacity))
                }

                // Category icon with Liquid Glass circle
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 42, height: 42)
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 0.75)
                        .frame(width: 42, height: 42)
                    Image(systemName: cat?.icon ?? "questionmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.store_name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(t.date)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        if let cat = cat {
                            Text("·").font(.system(size: 12)).foregroundStyle(.secondary)
                            Text(cat.localizedName)
                                .font(.system(size: 12))
                                .foregroundStyle(color.opacity(0.9))
                        } else {
                            Text("· ⚠ Kategori Seç")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                // Amount
                Text("\(t.type == "income" ? "+" : "−")₺\(String(format: "%.2f", t.amount))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(t.type == "income" ? ZColor.income : ZColor.expense)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelectionMode && isSelected
                          ? AppTheme.baseColor.opacity(0.08)
                          : Color(uiColor: .systemBackground).opacity(0.04))
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelectionMode && isSelected
                            ? AppTheme.baseColor.opacity(0.3)
                            : Color.white.opacity(0.06),
                        lineWidth: 0.75
                    )
            )
            .animation(.spring(response: 0.25), value: isSelected)
            .animation(.spring(response: 0.3), value: isSelectionMode)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            // Liquid Glass divider
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 0.5)
                .opacity(0.5)

            VStack(spacing: 10) {
                if isSelectionMode {
                    if selectedCount > 0 {
                        Button {
                            Task {
                                guard let uid = authVM.currentUserId else { return }
                                viewModel.transactions = transactions.filter { selectedIds.contains($0.id) }
                                await viewModel.saveAll(userId: uid)
                                let userType = authVM.userProfile?.userType ?? "personal"
                                await transactionVM.refreshData(userId: uid, userType: userType)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text(String(format: NSLocalizedString("bulk.saveAllCount", comment: "%d İşlemi Kaydet"), selectedCount))
                            }
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppTheme.accentGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppTheme.baseColor.opacity(0.35), radius: 14, x: 0, y: 4)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                            Text(NSLocalizedString("common.select", comment: "Seç") + " — En az 1 işlem seçin")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                } else {
                    // Default: save all
                    Button {
                        Task {
                            guard let uid = authVM.currentUserId else { return }
                            viewModel.transactions = transactions
                            await viewModel.saveAll(userId: uid)
                            let userType = authVM.userProfile?.userType ?? "personal"
                            await transactionVM.refreshData(userId: uid, userType: userType)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                            Text(String(format: NSLocalizedString("bulk.saveAllCount", comment: "%d İşlemi Kaydet"), transactions.count))
                        }
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.baseColor.opacity(0.35), radius: 14, x: 0, y: 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .padding(.top, 12)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Single Transaction Edit Sheet

struct BulkTransactionEditSheet: View {
    let transaction: StatementTransaction
    let categories: [Category]
    var onSave: (StatementTransaction) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var edited: StatementTransaction
    @State private var selectingCategory = false

    init(transaction: StatementTransaction, categories: [Category], onSave: @escaping (StatementTransaction) -> Void) {
        self.transaction = transaction
        self.categories = categories
        self.onSave = onSave
        self._edited = State(initialValue: transaction)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        let cat = categories.first(where: { $0.id.uuidString == edited.category_id })
                        let color = cat.map { Color(hex: $0.color) } ?? Color.orange

                        // Category picker button
                        Button { selectingCategory = true } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(.ultraThinMaterial).frame(width: 52, height: 52)
                                    Circle().fill(color.opacity(0.18)).frame(width: 52, height: 52)
                                    Circle().stroke(color.opacity(0.3), lineWidth: 1).frame(width: 52, height: 52)
                                    Image(systemName: cat?.icon ?? "questionmark.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(color)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cat?.localizedName ?? "Kategori Seç")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(color)
                                    Text("Değiştirmek için dokun")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 0.75))
                        }
                        .buttonStyle(.plain)

                        // Store name
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mağaza / Açıklama").font(.system(size: 12)).foregroundStyle(.secondary)
                                TextField("...", text: $edited.store_name)
                                    .font(.system(size: 16, weight: .semibold))
                            }.padding(16)
                        }

                        // Amount
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tutar").font(.system(size: 12)).foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("₺")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(AppTheme.baseColor)
                                    TextField("0.00", value: $edited.amount, format: .number.precision(.fractionLength(2)))
                                        .font(.system(size: 28, weight: .bold))
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(edited.type == "income" ? ZColor.income : .primary)
                                }
                            }.padding(16)
                        }

                        // Type toggle
                        HStack(spacing: 10) {
                            typeChip(label: "Gider", type: "expense", color: ZColor.expense)
                            typeChip(label: "Gelir", type: "income", color: ZColor.income)
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("İşlemi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "İptal")) { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.save", comment: "Kaydet")) {
                        onSave(edited)
                        Haptic.success()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.baseColor)
                }
            }
        }
        .sheet(isPresented: $selectingCategory) {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(categories) { cat in
                            Button {
                                edited.category_id = cat.id.uuidString
                                Haptic.selection()
                                selectingCategory = false
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle().fill(.ultraThinMaterial).frame(width: 60, height: 60)
                                        Circle().fill(Color(hex: cat.color).opacity(0.15)).frame(width: 60, height: 60)
                                        Image(systemName: cat.icon ?? "tag.fill").font(.title3)
                                            .foregroundStyle(Color(hex: cat.color))
                                    }
                                    Text(cat.localizedName).font(.caption).bold().foregroundStyle(.primary)
                                }
                            }
                        }
                    }.padding(20)
                }
                .navigationTitle(NSLocalizedString("bulk.pickCategory", comment: "Kategori Seç"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private func typeChip(label: String, type: String, color: Color) -> some View {
        let selected = edited.type == type
        return Button {
            withAnimation(.spring(response: 0.25)) { edited.type = type }
            Haptic.selection()
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selected ? color.opacity(0.15) : Color.clear)
                .foregroundStyle(selected ? color : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? color.opacity(0.4) : Color.secondary.opacity(0.15), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Picker (shared)

struct CategoryPickerFlow: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Binding var selectedId: String?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(transactionVM.categories) { cat in
                        Button {
                            selectedId = cat.id.uuidString
                            Haptic.selection()
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(.ultraThinMaterial).frame(width: 60, height: 60)
                                    Circle().fill(Color(hex: cat.color).opacity(0.15)).frame(width: 60, height: 60)
                                    Image(systemName: cat.icon ?? "tag.fill").font(.title3)
                                        .foregroundStyle(Color(hex: cat.color))
                                }
                                Text(cat.localizedName).font(.caption).bold().foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(NSLocalizedString("bulk.pickCategory", comment: "Kategori Seç"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
