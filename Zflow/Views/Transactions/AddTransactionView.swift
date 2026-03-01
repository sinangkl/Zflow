import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    var preselectedCategory: Category? = nil

    @State private var amount           = ""
    @State private var selectedCurrency: Currency = .try_
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var note             = ""
    @State private var date             = Date()
    @State private var isSaving         = false
    @State private var showCurrencyPicker = false
    @FocusState private var amountFocused: Bool

    private let quickCurrencies: [Currency] = [.try_, .USD, .EUR, .GBP]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var filteredCategories: [Category] {
        transactionVM.categories(for: selectedType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (Color(.systemGroupedBackground))
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        typeToggle
                        amountCard
                        currencyRow
                        categoryCard
                        metaCard
                        saveButton
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(ZColor.indigo)
                }
            }
            .onAppear {
                if let cat = preselectedCategory { selectedCategory = cat }
                if let cur = Currency(rawValue: transactionVM.primaryCurrency) {
                    selectedCurrency = cur
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { amountFocused = true }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selected: $selectedCurrency)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        HStack(spacing: 6) {
            typeButton(.income,  "Income",  "arrow.down.circle.fill", ZColor.income)
            typeButton(.expense, "Expense", "arrow.up.circle.fill",   ZColor.expense)
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func typeButton(_ type: TransactionType, _ label: String, _ icon: String, _ color: Color) -> some View {
        let sel = selectedType == type
        return Button {
            withAnimation(.spring(duration: 0.3)) {
                selectedType = type
                selectedCategory = nil
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
        .accessibilityLabel("Select \(label)")
    }

    // MARK: - Amount

    private var amountCard: some View {
        GlassCard {
            VStack(spacing: 6) {
                Text("Amount")
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
            Text("Currency")
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
                        Text("More")
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
                    Text("Category")
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
                    VStack(spacing: 12) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 32))
                            .foregroundColor(ZColor.labelTert)
                        Text("No categories yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ZColor.labelSec)
                        Text("Go to Settings → Categories to add one.")
                            .font(.system(size: 12))
                            .foregroundColor(ZColor.labelTert)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
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
                // iOS 26 HIG: Glass icon container, category color tint
                ZStack {
                    // Liquid Glass base
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.thinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(color.opacity(sel ? 0.22 : 0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    sel
                                    ? color.opacity(0.55)
                                    : Color.white.opacity(0.12),
                                    lineWidth: sel ? 1.5 : 0.5)
                        )
                        .shadow(
                            color: sel ? color.opacity(0.35) : .clear,
                            radius: 8, y: 3)
                        .scaleEffect(sel ? 1.06 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: sel)

                    Image(systemName: cat.icon ?? "tag.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: sel
                                    ? [color, color.opacity(0.7)]
                                    : [color.opacity(0.85), color.opacity(0.60)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                        .scaleEffect(sel ? 1.08 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: sel)
                }

                Text(cat.name)
                    .font(.system(size: 9, weight: sel ? .bold : .medium))
                    .foregroundColor(sel ? color : ZColor.labelSec)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note & Date

    private var metaCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    TextField("Note (optional)", text: $note)
                        .autocorrectionDisabled()
                }
                .padding(16)

                Divider().padding(.leading, 48)

                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Spacer()
                }
                .padding(16)
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button(action: save) {
            ZStack {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Transaction")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if amount.isEmpty {
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
                color: (selectedType == .income
                    ? ZColor.income
                    : ZColor.expense).opacity(amount.isEmpty ? 0 : 0.35),
                radius: 12, y: 5)
        }
        .disabled(amount.isEmpty || isSaving)
        .animation(.easeInOut(duration: 0.2), value: amount.isEmpty)
    }

    private func save() {
        guard let v = Double(amount.replacingOccurrences(of: ",", with: ".")),
              let uid = authVM.currentUserId else { return }
        Haptic.medium()
        isSaving = true
        Task {
            let ok = await transactionVM.addTransaction(
                userId: uid, amount: v, currency: selectedCurrency,
                type: selectedType, categoryId: selectedCategory?.id,
                note: note, date: date)
            isSaving = false
            if ok { dismiss() }
        }
    }
}

// MARK: - Currency Picker

struct CurrencyPickerView: View {
    @Binding var selected: Currency
    @Environment(\.dismiss) var dismiss
    @State private var search = ""

    private var filtered: [Currency] {
        guard !search.isEmpty else { return Currency.allCases }
        return Currency.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(search) ||
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { cur in
                Button {
                    selected = cur
                    Haptic.selection()
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(cur.flag)
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cur.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(cur.name)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(cur.symbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                        if selected == cur {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ZColor.indigo)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search currency")
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ZColor.indigo)
                }
            }
        }
    }
}

// MARK: - Edit Transaction

struct EditTransactionView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    let transaction: Transaction

    @State private var amount           = ""
    @State private var selectedCurrency: Currency = .try_
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var note             = ""
    @State private var date             = Date()
    @State private var isSaving         = false
    @State private var showCurrencyPicker = false
    @FocusState private var amountFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var filteredCategories: [Category] {
        transactionVM.categories(for: selectedType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (Color(.systemGroupedBackground)).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Type Toggle
                        HStack(spacing: 6) {
                            ForEach(TransactionType.allCases, id: \.self) { type in
                                let sel = selectedType == type
                                let color: Color = type == .income ? ZColor.income : ZColor.expense
                                Button {
                                    withAnimation(.spring(duration: 0.3)) {
                                        selectedType = type; selectedCategory = nil
                                    }; Haptic.selection()
                                } label: {
                                    Text(type.displayName)
                                        .font(.system(size: 15, weight: .bold))
                                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                                        .background(sel ? color.opacity(0.15) : Color.clear)
                                        .foregroundColor(sel ? color : .secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? color.opacity(0.4) : .clear, lineWidth: 1.5))
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

                        // Amount
                        GlassCard {
                            HStack(alignment: .bottom, spacing: 8) {
                                Text(selectedCurrency.symbol)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(ZColor.indigo)
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .keyboardType(.decimalPad).focused($amountFocused)
                            }.padding(20)
                        }

                        // Currency quick row
                        HStack(spacing: 8) {
                            ForEach([Currency.try_, .USD, .EUR, .GBP], id: \.self) { cur in
                                let sel = selectedCurrency == cur
                                Button { selectedCurrency = cur; Haptic.selection() } label: {
                                    Text("\(cur.flag) \(cur.rawValue)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(sel ? ZColor.indigo.opacity(0.15) : Color(.secondarySystemGroupedBackground)))
                                        .foregroundColor(sel ? ZColor.indigo : .secondary)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(sel ? ZColor.indigo.opacity(0.5) : .clear, lineWidth: 1.5))
                                }.buttonStyle(.plain)
                            }
                            Spacer()
                            Button { showCurrencyPicker = true } label: {
                                Image(systemName: "ellipsis.circle.fill").font(.system(size: 22)).foregroundColor(ZColor.indigo)
                            }
                        }

                        // Categories
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Category").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(filteredCategories) { cat in
                                        let sel = selectedCategory?.id == cat.id
                                        let c = Color(hex: cat.color)
                                        Button { withAnimation(.spring(duration: 0.2)) { selectedCategory = sel ? nil : cat }; Haptic.selection() } label: {
                                            VStack(spacing: 6) {
                                                ZStack {
                                                    Circle().fill(c.opacity(sel ? 0.25 : 0.1)).frame(width: 42, height: 42)
                                                    Image(systemName: cat.icon ?? "tag.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(c)
                                                }
                                                Text(cat.name).font(.system(size: 9, weight: .semibold)).foregroundColor(sel ? c : .secondary).lineLimit(2).multilineTextAlignment(.center)
                                            }
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(RoundedRectangle(cornerRadius: 12).fill(sel ? c.opacity(0.08) : Color(.tertiarySystemFill)))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? c.opacity(0.5) : .clear, lineWidth: 1.5))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }.padding(16)
                        }

                        // Note & Date
                        GlassCard {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Image(systemName: "note.text").foregroundColor(.secondary).frame(width: 20)
                                    TextField("Note", text: $note).autocorrectionDisabled()
                                }.padding(16)
                                Divider().padding(.leading, 48)
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar").foregroundColor(.secondary).frame(width: 20)
                                    DatePicker("", selection: $date, displayedComponents: .date).labelsHidden().datePickerStyle(.compact)
                                    Spacer()
                                }.padding(16)
                            }
                        }

                        // Save
                        Button(action: save) {
                            ZStack {
                                if isSaving { ProgressView().tint(.white) }
                                else { Text("Update Transaction").font(.system(size: 17, weight: .bold)) }
                            }
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(AppTheme.accentGradient).foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }.disabled(amount.isEmpty || isSaving).opacity(amount.isEmpty ? 0.4 : 1)
                    }
                    .padding(16).padding(.bottom, 20)
                }
            }
            .navigationTitle("Edit Transaction").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(ZColor.indigo)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Done") { amountFocused = false }
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selected: $selectedCurrency).presentationDetents([.medium])
            }
            .onAppear {
                amount           = String(format: "%.2f", transaction.amount)
                selectedCurrency = Currency(rawValue: transaction.currency) ?? .try_
                selectedType     = TransactionType(rawValue: transaction.type ?? "expense") ?? .expense
                selectedCategory = transactionVM.category(for: transaction.categoryId)
                note             = transaction.note ?? ""
                date             = transaction.date ?? Date()
            }
        }
    }

    private func save() {
        guard let v = Double(amount.replacingOccurrences(of: ",", with: ".")),
              let uid = authVM.currentUserId else { return }
        Haptic.medium(); isSaving = true
        Task {
            await transactionVM.updateTransaction(
                id: transaction.id, userId: uid, amount: v, currency: selectedCurrency,
                type: selectedType, categoryId: selectedCategory?.id, note: note, date: date)
            isSaving = false; dismiss()
        }
    }
}
