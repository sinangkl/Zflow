import SwiftUI

struct RecurringManagerView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    @State private var editingItem: RecurringTransaction?
    @State private var showAddRecurring = false

    private var items: [RecurringTransaction] {
        recurringVM.recurringTransactions
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()

                if items.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "repeat.circle")
                            .font(.system(size: 48))
                            .foregroundColor(ZColor.labelTert)
                        Text(Localizer.shared.l("recurring.emptyTitle"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ZColor.label)
                        Text(Localizer.shared.l("recurring.emptySubtitle"))
                            .font(.system(size: 14))
                            .foregroundColor(ZColor.labelSec)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            recurringRow(item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingItem = item
                                    Haptic.selection()
                                }
                        }
                        .onDelete { idxSet in
                            for idx in idxSet {
                                let item = items[idx]
                                Task {
                                    await recurringVM.delete(id: item.id)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(Localizer.shared.l("recurring.manageTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localizer.shared.l("common.done")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddRecurring = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.baseColor)
                    }
                }
            }
            .sheet(item: $editingItem) { item in
                EditRecurringView(item: item)
                    .environmentObject(transactionVM)
                    .environmentObject(recurringVM)
            }
            .sheet(isPresented: $showAddRecurring) {
                AddRecurringView()
                    .environmentObject(transactionVM)
                    .environmentObject(recurringVM)
                    .environmentObject(authVM)
            }
        }
    }

    private func recurringRow(_ item: RecurringTransaction) -> some View {
        let isIncome = item.transactionType == "income"
        let cat = item.categoryId.flatMap { transactionVM.category(for: $0) }
        let tint = isIncome ? ZColor.income : ZColor.expense

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ZColor.label)
                HStack(spacing: 6) {
                    Text((item.expectedAmount ?? 0).formattedCurrency(code: item.currency))
                    Text("·")
                    Text(String(format: Localizer.shared.l("recurring.dayOfMonth"), item.dayOfMonth))
                }
                .font(.system(size: 12))
                .foregroundColor(ZColor.labelSec)

                if let cat {
                    Text(cat.localizedName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: cat.color))
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.isActive },
                set: { value in
                    Task {
                        await recurringVM.toggleActive(id: item.id, isActive: value)
                    }
                }
            ))
            .labelsHidden()
        }
    }
}

struct EditRecurringView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @Environment(\.dismiss) var dismiss

    let item: RecurringTransaction

    @State private var title: String
    @State private var amount: String
    @State private var currency: Currency
    @State private var type: TransactionType
    @State private var dayOfMonth: Int
    @State private var selectedCategory: Category?
    @State private var isActive: Bool
    @State private var isSaving = false

    private let days = Array(1...28)

    init(item: RecurringTransaction) {
        self.item = item
        _title = State(initialValue: item.title)
        _amount = State(initialValue: item.expectedAmount != nil ? String(format: "%.2f", item.expectedAmount!) : "")
        _currency = State(initialValue: Currency(rawValue: item.currency) ?? .try_)
        _type = State(initialValue: TransactionType(rawValue: item.transactionType) ?? .expense)
        _dayOfMonth = State(initialValue: item.dayOfMonth)
        _isActive = State(initialValue: item.isActive)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(Localizer.shared.l("recurring.details")) {
                    TextField(Localizer.shared.l("common.name"), text: $title)
                    TextField(Localizer.shared.l("transaction.amount"), text: $amount)
                        .keyboardType(.decimalPad)
                    Picker(Localizer.shared.l("transaction.currency"), selection: $currency) {
                        ForEach(Currency.allCases) { cur in
                            Text("\(cur.flag) \(cur.rawValue)").tag(cur)
                        }
                    }
                    Picker(Localizer.shared.l("transaction.type"), selection: $type) {
                        Text(Localizer.shared.l("transaction.expense")).tag(TransactionType.expense)
                        Text(Localizer.shared.l("transaction.income")).tag(TransactionType.income)
                    }
                    Picker(Localizer.shared.l("recurring.dayPicker"), selection: $dayOfMonth) {
                        ForEach(days, id: \.self) { d in
                            Text("\(d)").tag(d)
                        }
                    }
                    Toggle(Localizer.shared.l("recurring.isActive"), isOn: $isActive)
                }

                Section(Localizer.shared.l("transaction.category")) {
                    Picker(Localizer.shared.l("transaction.category"), selection: Binding(
                        get: { selectedCategory?.id },
                        set: { newId in
                            selectedCategory = newId.flatMap { transactionVM.category(for: $0) }
                        }
                    )) {
                        Text(Localizer.shared.l("common.none")).tag(UUID?.none)
                        ForEach(transactionVM.categories(for: type)) { cat in
                            Text(cat.localizedName).tag(UUID?(cat.id))
                        }
                    }
                }
            }
            .navigationTitle(Localizer.shared.l("recurring.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localizer.shared.l("common.cancel")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Localizer.shared.l("common.save")) {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(Localizer.shared.l("common.done")) {
                            hideKeyboard()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.baseColor)
                    }
                }
            }
            .onAppear {
                if let cid = item.categoryId {
                    selectedCategory = transactionVM.category(for: cid)
                }
            }
        }
    }

    private func save() {
        let value = Double(amount.replacingOccurrences(of: ",", with: "."))
        isSaving = true
        Task {
            await recurringVM.update(
                id: item.id,
                title: title.trimmingCharacters(in: .whitespaces),
                categoryId: selectedCategory?.id,
                transactionType: type,
                expectedAmount: value,
                currency: currency,
                dayOfMonth: dayOfMonth,
                isActive: isActive
            )
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Add Recurring View
struct AddRecurringView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var currency: Currency = .try_
    @State private var type: TransactionType = .expense
    @State private var dayOfMonth: Int = min(max(1, Calendar.current.component(.day, from: Date())), 28)
    @State private var selectedCategory: Category?
    @State private var isSaving = false

    private let days = Array(1...28)

    var body: some View {
        NavigationStack {
            Form {
                Section(Localizer.shared.l("recurring.details")) {
                    TextField(Localizer.shared.l("common.name"), text: $title)
                    TextField(Localizer.shared.l("transaction.amount"), text: $amount)
                        .keyboardType(.decimalPad)
                    Picker(Localizer.shared.l("transaction.currency"), selection: $currency) {
                        ForEach(Currency.allCases) { cur in
                            Text("\(cur.flag) \(cur.rawValue)").tag(cur)
                        }
                    }
                    Picker(Localizer.shared.l("transaction.type"), selection: $type) {
                        Text(Localizer.shared.l("transaction.expense")).tag(TransactionType.expense)
                        Text(Localizer.shared.l("transaction.income")).tag(TransactionType.income)
                    }
                    Picker(Localizer.shared.l("recurring.dayPicker"), selection: $dayOfMonth) {
                        ForEach(days, id: \.self) { d in
                            Text("\(d)").tag(d)
                        }
                    }
                }

                Section(Localizer.shared.l("transaction.category")) {
                    Picker(Localizer.shared.l("transaction.category"), selection: Binding(
                        get: { selectedCategory?.id },
                        set: { newId in
                            selectedCategory = newId.flatMap { transactionVM.category(for: $0) }
                        }
                    )) {
                        Text(Localizer.shared.l("common.none")).tag(UUID?.none)
                        ForEach(transactionVM.categories(for: type)) { cat in
                            Text(cat.localizedName).tag(UUID?(cat.id))
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("settings.recurring.manage", comment: "")) // Or a + localized string
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localizer.shared.l("common.cancel")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Localizer.shared.l("common.save")) {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(Localizer.shared.l("common.done")) {
                            hideKeyboard()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.baseColor)
                    }
                }
            }
        }
    }

    private func save() {
        let value = Double(amount.replacingOccurrences(of: ",", with: "."))
        guard let uid = authVM.currentUserId else { return }
        isSaving = true
        Task {
            _ = await recurringVM.add(
                userId: uid,
                title: title.trimmingCharacters(in: .whitespaces),
                categoryId: selectedCategory?.id,
                transactionType: type,
                expectedAmount: value,
                currency: currency,
                dayOfMonth: dayOfMonth
            )
            isSaving = false
            dismiss()
        }
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
