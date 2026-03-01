import SwiftUI

import SwiftUI

struct EditTransactionView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    let transaction: Transaction

    @State private var amount: String
    @State private var selectedCurrency: Currency
    @State private var selectedType: TransactionType
    @State private var selectedCategory: Category?
    @State private var note: String
    @State private var date: Date
    @State private var isSaving = false
    @State private var showCurrencyPicker = false
    @State private var showDeleteConfirm = false
    @FocusState private var amountFocused: Bool

    private let quickCurrencies: [Currency] = [.try_, .USD, .EUR, .GBP]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var filteredCategories: [Category] {
        transactionVM.categories(for: selectedType)
    }
    
    private var hasChanges: Bool {
        guard let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) else { return false }
        
        return amt != transaction.amount ||
            selectedCurrency.rawValue != transaction.currency ||
            selectedType.rawValue != (transaction.type ?? "expense") ||
            selectedCategory?.id != transaction.categoryId ||
            note != (transaction.note ?? "") ||
            !Calendar.current.isDate(date, inSameDayAs: transaction.date ?? Date())
    }

    init(transaction: Transaction) {
        self.transaction = transaction
        
        // Initialize state
        _amount = State(initialValue: String(format: "%.2f", transaction.amount))
        _selectedCurrency = State(initialValue: Currency(rawValue: transaction.currency) ?? .try_)
        _selectedType = State(initialValue: TransactionType(rawValue: transaction.type ?? "expense") ?? .expense)
        _note = State(initialValue: transaction.note ?? "")
        _date = State(initialValue: transaction.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        typeToggle
                        amountCard
                        currencyRow
                        categoryCard
                        metaCard
                        
                        VStack(spacing: 12) {
                            saveButton
                            deleteButton
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(ZColor.indigo)
                }
            }
            .onAppear {
                // Set initial category
                if let catId = transaction.categoryId {
                    selectedCategory = transactionVM.categories.first { $0.id == catId }
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selected: $selectedCurrency)
                    .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Delete Transaction",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteTransaction()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        HStack(spacing: 6) {
            typeButton(.income,  NSLocalizedString("dashboard.income", comment: ""),  "arrow.down.circle.fill", ZColor.income)
            typeButton(.expense, NSLocalizedString("dashboard.expense", comment: ""), "arrow.up.circle.fill",   ZColor.expense)
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func typeButton(_ type: TransactionType, _ label: String, _ icon: String, _ color: Color) -> some View {
        let sel = selectedType == type
        return Button {
            withAnimation(.spring(duration: 0.3)) {
                selectedType = type
                // Kategoriyi sıfırla çünkü gelir/gider kategorileri farklı
                if selectedCategory?.type != nil && selectedCategory?.type != type.rawValue {
                    selectedCategory = nil
                }
            }
            Haptic.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(sel ? color.opacity(0.15) : Color.clear)
            .foregroundColor(sel ? color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(sel ? color.opacity(0.4) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount

    private var amountCard: some View {
        GlassCard {
            VStack(spacing: 6) {
                Text(NSLocalizedString("transaction.amount", comment: "Amount"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: 8) {
                    Text(selectedCurrency.symbol)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(ZColor.indigo)

                    TextField("0.00", text: $amount)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .frame(height: 48)
                }

                if let parsed = Double(amount.replacingOccurrences(of: ",", with: ".")),
                   transactionVM.primaryCurrency != selectedCurrency.rawValue {
                    let converted = CurrencyConverter.convert(
                        amount: parsed,
                        from: selectedCurrency.rawValue,
                        to: transactionVM.primaryCurrency)
                    Text("≈ \(converted.formattedCurrency(code: transactionVM.primaryCurrency))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Currency

    private var currencyRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("transaction.currency", comment: "Currency"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(quickCurrencies) { cur in
                    currencyChip(cur)
                }
                Button { showCurrencyPicker = true; Haptic.selection() } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .bold))
                        Text(NSLocalizedString("common.more", comment: "More"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemGroupedBackground)))
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private func currencyChip(_ cur: Currency) -> some View {
        let sel = selectedCurrency == cur
        return Button {
            selectedCurrency = cur; Haptic.selection()
        } label: {
            VStack(spacing: 3) {
                Text(cur.flag)
                    .font(.system(size: 18))
                Text(cur.rawValue)
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(sel ? ZColor.indigo.opacity(0.15) : Color(.secondarySystemGroupedBackground)))
            .foregroundColor(sel ? ZColor.indigo : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(sel ? ZColor.indigo.opacity(0.5) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category

    private var categoryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(NSLocalizedString("transaction.category", comment: "Category"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let sel = selectedCategory {
                        HStack(spacing: 4) {
                            Image(systemName: sel.icon ?? "tag")
                                .font(.system(size: 11))
                            Text(sel.name)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: sel.color).opacity(0.15)))
                        .foregroundColor(Color(hex: sel.color))
                    }
                }

                if filteredCategories.isEmpty {
                    Text(NSLocalizedString("category.notFound", comment: "No categories found"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredCategories) { cat in
                            categoryCell(cat)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func categoryCell(_ cat: Category) -> some View {
        let sel   = selectedCategory?.id == cat.id
        let color = Color(hex: cat.color)
        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) {
                selectedCategory = sel ? nil : cat
            }
            Haptic.selection()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(sel ? 0.22 : 0.10))
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    sel ? color.opacity(0.55) : Color.white.opacity(0.12),
                                    lineWidth: sel ? 1.5 : 0.5)
                        )
                        .scaleEffect(sel ? 1.06 : 1.0)

                    Image(systemName: cat.icon ?? "tag.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                        .scaleEffect(sel ? 1.08 : 1.0)
                }

                Text(cat.name)
                    .font(.system(size: 9, weight: sel ? .bold : .medium))
                    .foregroundColor(sel ? color : ZColor.labelSec)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: sel)
    }

    // MARK: - Meta (Date + Note)

    private var metaCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                // Date
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    DatePicker(
                        NSLocalizedString("transaction.date", comment: "Date"),
                        selection: $date,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                }
                .padding(16)

                Divider().padding(.leading, 48)

                // Note
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                        .padding(.top, 2)
                    
                    TextField(NSLocalizedString("transaction.note", comment: "Note (optional)"), text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                }
                .padding(16)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: save) {
            ZStack {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(NSLocalizedString("common.save", comment: "Save Changes"))
                            .font(.system(size: 17, weight: .bold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if !hasChanges || amount.isEmpty {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ZColor.indigo.opacity(0.4))
                    } else if selectedType == .income {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.incomeGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.expenseGradient)
                    }
                }
            )
            .foregroundColor(.white)
            .shadow(
                color: (selectedType == .income ? ZColor.income : ZColor.expense)
                    .opacity(!hasChanges || amount.isEmpty ? 0 : 0.35),
                radius: 12, y: 5)
        }
        .disabled(!hasChanges || amount.isEmpty || isSaving)
        .animation(.easeInOut(duration: 0.2), value: hasChanges)
        .animation(.easeInOut(duration: 0.2), value: amount.isEmpty)
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
            Haptic.light()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                Text(NSLocalizedString("common.delete", comment: "Delete Transaction"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
            .foregroundColor(ZColor.expense)
        }
        .disabled(isSaving)
    }

    // MARK: - Actions

    private func save() {
        guard let uid = authVM.currentUserId,
              let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) else { return }

        Haptic.medium()
        isSaving = true

        Task {
            await transactionVM.updateTransaction(
                id: transaction.id,
                userId: uid,
                amount: amt,
                currency: selectedCurrency,
                type: selectedType,
                categoryId: selectedCategory?.id,
                note: note.isEmpty ? nil : note,
                date: date
            )

            isSaving = false
            Haptic.success()
            dismiss()
        }
    }
    
    private func deleteTransaction() {
        guard let uid = authVM.currentUserId else { return }
        
        Haptic.medium()
        
        Task {
            await transactionVM.deleteTransaction(id: transaction.id, userId: uid)
            Haptic.success()
            dismiss()
        }
    }
}

// MARK: - Currency Picker

struct CurrencyPickerView: View {
    @Binding var selected: Currency
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    private var filtered: [Currency] {
        if searchText.isEmpty {
            return Currency.allCases
        }
        return Currency.allCases.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { currency in
                    Button {
                        selected = currency
                        Haptic.selection()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(currency.flag)
                                .font(.system(size: 28))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currency.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(currency.rawValue)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selected == currency {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ZColor.indigo)
                                    .font(.system(size: 20))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(NSLocalizedString("transaction.currency", comment: "Currency"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: NSLocalizedString("common.search", comment: "Search"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(ZColor.indigo)
                }
            }
        }
    }
}
