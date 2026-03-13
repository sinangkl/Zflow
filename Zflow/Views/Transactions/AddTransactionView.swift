import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddTransactionView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var scheduledPaymentVM: ScheduledPaymentViewModel
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @EnvironmentObject var calMgr: CalendarManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    var preselectedCategory: Category? = nil
    var scanData: ScannedReceipt? = nil
    var onSuccess: ((TransactionType, Double, Currency) -> Void)? = nil

    @State private var amount           = ""
    @State private var selectedCurrency: Currency = .try_
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var note             = ""
    @State private var date             = Date()
    @State private var showCurrencyPicker = false
    @State private var showRecurringAlert = false
    @State private var savedAmountForRecurring: Double = 0
    @State private var showReceiptScanner  = false
    @FocusState private var amountFocused: Bool

    // MARK: - Attachments Placeholder
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var showAttachmentOptions = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var attachmentData: Data?
    @State private var attachmentName: String?

    init(scan: ScannedReceipt? = nil, preselectedCategory: Category? = nil, onSuccess: ((TransactionType, Double, Currency) -> Void)? = nil) {
        self.preselectedCategory = preselectedCategory
        self.scanData = scan
        self.onSuccess = onSuccess
        if let s = scan {
            _amount = State(initialValue: String(format: "%.2f", s.amount))
            _note = State(initialValue: s.note)
            _date = State(initialValue: s.date)
            _selectedType = State(initialValue: s.type == "income" ? .income : .expense)
            _selectedCurrency = State(initialValue: Currency(rawValue: s.currency) ?? .try_)
        }
    }

    private let quickCurrencies: [Currency] = [.try_, .USD, .EUR, .GBP]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var filteredCategories: [Category] {
        transactionVM.categories(for: selectedType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
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
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Localizer.shared.l("transaction.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localizer.shared.l("common.cancel")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showReceiptScanner = true
                    } label: {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.baseColor)
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(Localizer.shared.l("common.done")) { amountFocused = false }
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.baseColor)
                    }
                }
            }
            .onAppear {
                if let cat = preselectedCategory { selectedCategory = cat }
                if let cur = Currency(rawValue: transactionVM.primaryCurrency) {
                    selectedCurrency = cur
                }
                
                // Automatic Category Selection from AI Scan
                if let scan = scanData, selectedCategory == nil {
                    if let catId = scan.categoryId {
                        // Look for a category that matches the AI identifier
                        // Standard matching (case-insensitive name match)
                        let match = transactionVM.categories(for: selectedType).first {
                            $0.name.lowercased() == catId.lowercased()
                        }
                        if let match {
                            selectedCategory = match
                        }
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { amountFocused = true }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selected: $selectedCurrency)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerSheet()
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
            .alert(
                Localizer.shared.l("recurring.alertTitle"),
                isPresented: $showRecurringAlert
            ) {
                Button(Localizer.shared.l("recurring.addReminder"), role: nil) {
                    addRecurringReminder()
                    dismiss()
                }
                Button(Localizer.shared.l("common.cancel"), role: .cancel) {
                    dismiss()
                }
            } message: {
                let typeLabel = selectedType == .income
                    ? Localizer.shared.l("transaction.income").lowercased()
                    : Localizer.shared.l("transaction.expense").lowercased()
                Text(Localizer.shared.l("recurring.alertMessage")
                    .replacingOccurrences(of: "{type}", with: typeLabel))
            }
        }
    }

    // MARK: - Recurring Reminder

    private func addRecurringReminder() {
        guard let uid = authVM.currentUserId else { return }
        let dayOfMonth = Calendar.current.component(.day, from: date)
        let amt = Double(amount.replacingOccurrences(of: ",", with: "."))
        let cur = selectedCurrency
        let type = selectedType
        let cat = selectedCategory
        let title = cat?.name ?? note
        let vm = recurringVM

        Task {
            _ = await vm.add(
                userId: uid,
                title: title.isEmpty ? (type == .income ? "Gelir" : "Gider") : title,
                categoryId: cat?.id,
                transactionType: type,
                expectedAmount: amt,
                currency: cur,
                dayOfMonth: dayOfMonth
            )
        }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        let activeColor = selectedType == .income ? ZColor.income : ZColor.expense
        return HStack(spacing: 6) {
            typeButton(.income,  Localizer.shared.l("transaction.income"),  "arrow.up.circle.fill",    ZColor.income)
            typeButton(.expense, Localizer.shared.l("transaction.expense"), "arrow.down.circle.fill",  ZColor.expense)
        }
        .padding(5)
        // Liquid Glass container — ultraThinMaterial + subtle active-color ambient tint
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(activeColor.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedType)
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
                    .eliteBody()
                Text(label)
                    .eliteFont(size: 15, weight: .semibold, textStyle: .body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            // Selected: color + ultraThinMaterial blend for Liquid Glass feel
            .background(
                Group {
                    if sel {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(color.opacity(0.18))
                            )
                    } else {
                        Color.clear
                    }
                }
            )
            .foregroundStyle(sel ? color : ThemeColors.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(sel ? color.opacity(0.45) : .clear, lineWidth: 1.5))
            .shadow(color: sel ? color.opacity(0.20) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(label)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Amount

    private var amountCard: some View {
        GlassCard {
            VStack(spacing: 6) {
                Text("Amount")
                    .eliteCaption()
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: 8) {
                    Text(selectedCurrency.symbol)
                        .eliteBody()
                        .foregroundColor(AppTheme.baseColor)

                    TextField("0.00", text: $amount)
                        .eliteHeroBalance()
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .frame(height: 52)
                }

                if let parsed = Double(amount.replacingOccurrences(of: ",", with: ".")),
                   transactionVM.primaryCurrency != selectedCurrency.rawValue {
                    let converted = CurrencyConverter.convert(
                        amount: parsed,
                        from: selectedCurrency.rawValue,
                        to: transactionVM.primaryCurrency)
                    Text("≈ \(converted.formattedCurrency(code: transactionVM.primaryCurrency))")
                        .eliteCaption()
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
            Text(Localizer.shared.l("transaction.currency"))
                .eliteCaption()
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(quickCurrencies) { cur in
                    currencyChip(cur)
                }
                Button { showCurrencyPicker = true; Haptic.selection() } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "ellipsis")
                            .eliteBody()
                        Text(Localizer.shared.l("common.more"))
                            .eliteCaption()
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
                    .eliteBody()
                Text(cur.rawValue)
                    .eliteCaption()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(sel ? AppTheme.baseColor.opacity(0.15) : Color(.secondarySystemGroupedBackground)))
            .foregroundColor(sel ? AppTheme.baseColor : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(sel ? AppTheme.baseColor.opacity(0.5) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category

    private var categoryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Category")
                        .eliteCaption()
                        .foregroundColor(.secondary)
                    Spacer()
                    if let sel = selectedCategory {
                        HStack(spacing: 4) {
                            Image(systemName: sel.icon ?? "tag")
                                .eliteCaption()
                            Text(sel.name)
                                .eliteCaption()
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
                            .eliteTitle()
                            .foregroundColor(ZColor.labelTert)
                        Text("No categories yet")
                            .eliteTitle()
                            .foregroundColor(ZColor.labelSec)
                        Text("Go to Settings → Categories to add one.")
                            .eliteCaption()
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
                        .eliteBody()
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

                Text(cat.localizedName)
                    .eliteCaption()
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
        GlassCard(cornerRadius: 20) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Note (optional)", text: $note, axis: .vertical)
                            .autocorrectionDisabled()
                            .lineLimit(1...3)
                            .font(.system(size: 15, weight: .regular))
                    }
                }
                .padding(14)

                Divider().padding(.leading, 50).padding(.vertical, 2)

                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 24)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Spacer()
                }
                .padding(14)
                
                Divider()
                
                Button {
                    showAttachmentOptions = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: attachmentData != nil ? "doc.fill" : "paperclip")
                            .foregroundColor(attachmentData != nil ? AppTheme.baseColor : .secondary)
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 24)
                        Text(attachmentData != nil ? (attachmentName ?? "Belge Eklendi") : "Fatura, Makbuz veya PDF Ekle")
                            .font(.system(size: 15))
                            .foregroundColor(attachmentData != nil ? AppTheme.baseColor : .secondary)
                        Spacer()
                    }
                    .padding(14)
                }
                .confirmationDialog("Eklenti Türü", isPresented: $showAttachmentOptions) {
                    Button("Fotoğraf Kütüphanesi") { showPhotoPicker = true }
                    Button("Dosyalar (PDF, vb.)") { showFilePicker = true }
                    if attachmentData != nil {
                        Button("Eklentiyi Kaldır", role: .destructive) {
                            attachmentData = nil
                            attachmentName = nil
                        }
                    }
                    Button("İptal", role: .cancel) {}
                }

            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf, .image, .item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    attachmentName = url.lastPathComponent
                    _ = url.startAccessingSecurityScopedResource()
                    attachmentData = try? Data(contentsOf: url)
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("❌ File Import Error: \(error)")
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    attachmentData = data
                    attachmentName = "Fotoğraf"
                }
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        let canSave = !amount.isEmpty
        return Button(action: save) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .eliteFont(size: 16, weight: .semibold, textStyle: .body)
                Text("Save Transaction")
                    .eliteFont(size: 16, weight: .semibold, textStyle: .body)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Group {
                    if !canSave {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.baseColor.opacity(0.3))
                    } else if selectedType == .income {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.incomeGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.expenseGradient)
                    }
                }
            )
            .foregroundStyle(.white)
            .shadow(
                color: (selectedType == .income ? ZColor.income : ZColor.expense)
                    .opacity(canSave ? 0.25 : 0),
                radius: 8, y: 3)
        }
        .disabled(!canSave)
        .animation(.easeInOut(duration: 0.2), value: canSave)
        .accessibilityLabel("Save Transaction")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Optimistic Save
    // Instantly dismisses with haptic feedback; network call continues in background.
    // If the request fails, TransactionViewModel will surface the error via its published state.

    private func save() {
        guard let v = Double(amount.replacingOccurrences(of: ",", with: ".")),
              let uid = authVM.currentUserId else { return }

        // Recurring alert: Bugünkü veya geçmiş tarihli işlemler için sor
        let isFutureDate = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
        let shouldAskRecurring = !isFutureDate

        Haptic.success()   // Immediate tactile confirmation

        if shouldAskRecurring {
            savedAmountForRecurring = v
            // Do NOT dismiss — let the alert show first
        } else {
            dismiss()      // Optimistic dismiss for future-date transactions
        }

        // Capture all references before view deallocates
        let vm          = transactionVM
        let schedVM     = scheduledPaymentVM
        let cal         = calMgr
        let savedType   = selectedType
        let savedCat    = selectedCategory
        let savedNote   = note
        let savedDate   = date
        let savedCur    = selectedCurrency

        Task {
            let isFuture = Calendar.current.startOfDay(for: savedDate) > Calendar.current.startOfDay(for: Date())
            let eventTitle = savedCat?.name ?? (isFuture ? "Scheduled \(savedType.displayName)" : savedType.displayName)

            if isFuture {
                var eventId: String? = nil
                if cal.isAuthorized {
                    eventId = cal.addEvent(
                        title: eventTitle, amount: v,
                        currency: savedCur.rawValue,
                        date: savedDate,
                        notes: savedNote.isEmpty ? nil : savedNote
                    )
                }
                _ = await schedVM.addScheduledPayment(
                    userId: uid,
                    title: eventTitle,
                    amount: v,
                    currency: savedCur,
                    type: savedType,
                    categoryId: savedCat?.id,
                    note: savedNote.isEmpty ? nil : savedNote,
                    scheduledDate: savedDate,
                    calendarEventId: eventId
                )
            } else {
                let initialStatus = (authVM.userProfile?.familyId != nil && authVM.userProfile?.familyRole != "admin") ? "pending" : "approved"
                let ok = await vm.addTransaction(
                    userId: uid, amount: v, currency: savedCur,
                    type: savedType, categoryId: savedCat?.id,
                    note: savedNote, date: savedDate, status: initialStatus, attachmentURL: nil)

                if ok && cal.isAuthorized {
                    _ = cal.addEvent(
                        title: eventTitle, amount: v,
                        currency: savedCur.rawValue,
                        date: savedDate,
                        notes: savedNote.isEmpty ? nil : savedNote,
                        isAllDay: true
                    )
                }
            }
            
            DispatchQueue.main.async {
                onSuccess?(savedType, v, savedCur)
                if shouldAskRecurring {
                    showRecurringAlert = true
                }
            }
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
                            .eliteTitle()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cur.rawValue)
                                .eliteBody()
                                .foregroundColor(.primary)
                            Text(cur.name)
                                .eliteCaption()
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(cur.symbol)
                            .eliteTitle()
                            .foregroundColor(.secondary)
                        if selected == cur {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.baseColor)
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
                        .foregroundColor(AppTheme.baseColor)
                }
            }
        }
    }
}

// MARK: - Edit Transaction

struct EditTransactionView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    let transaction: Transaction

    @State private var amount           = ""
    @State private var selectedCurrency: Currency = .try_
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var note             = ""
    @State private var date             = Date()
    @State private var showCurrencyPicker = false
    @FocusState private var amountFocused: Bool
    @State private var showRecurringAlert = false
    @State private var savedAmountForRecurring: Double = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var filteredCategories: [Category] {
        transactionVM.categories(for: selectedType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Type Toggle — Liquid Glass
                        let activeColor: Color = selectedType == .income ? ZColor.income : ZColor.expense
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
                                        .eliteFont(size: 15, weight: .semibold, textStyle: .body)
                                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                                        .background(Group {
                                            if sel {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(.ultraThinMaterial)
                                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.18)))
                                            } else { Color.clear }
                                        })
                                        .foregroundStyle(sel ? color : ThemeColors.textSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? color.opacity(0.45) : .clear, lineWidth: 1.5))
                                        .shadow(color: sel ? color.opacity(0.20) : .clear, radius: 6, y: 2)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Select \(type.displayName)")
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(activeColor.opacity(0.25), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedType)

                        // Amount
                        GlassCard {
                            HStack(alignment: .bottom, spacing: 8) {
                                Text(selectedCurrency.symbol)
                                    .eliteTitle()
                                    .foregroundColor(AppTheme.baseColor)
                                TextField("0.00", text: $amount)
                                    .eliteHeroBalance()
                                    .keyboardType(.decimalPad).focused($amountFocused)
                            }.padding(20)
                        }

                        // Currency quick row
                        HStack(spacing: 8) {
                            ForEach([Currency.try_, .USD, .EUR, .GBP], id: \.self) { cur in
                                let sel = selectedCurrency == cur
                                Button { selectedCurrency = cur; Haptic.selection() } label: {
                                    Text("\(cur.flag) \(cur.rawValue)")
                                        .eliteCaption()
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(sel ? AppTheme.baseColor.opacity(0.15) : Color(.secondarySystemGroupedBackground)))
                                        .foregroundColor(sel ? AppTheme.baseColor : .secondary)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(sel ? AppTheme.baseColor.opacity(0.5) : .clear, lineWidth: 1.5))
                                }.buttonStyle(.plain)
                            }
                            Spacer()
                            Button { showCurrencyPicker = true } label: {
                                Image(systemName: "ellipsis.circle.fill").eliteTitle().foregroundColor(AppTheme.baseColor)
                            }
                        }

                        // Categories
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Category").eliteCaption().foregroundColor(.secondary)
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(filteredCategories) { cat in
                                        let sel = selectedCategory?.id == cat.id
                                        let c = Color(hex: cat.color)
                                        Button { withAnimation(.spring(duration: 0.2)) { selectedCategory = sel ? nil : cat }; Haptic.selection() } label: {
                                            VStack(spacing: 6) {
                                                ZStack {
                                                    Circle().fill(c.opacity(sel ? 0.25 : 0.1)).frame(width: 42, height: 42)
                                                    Image(systemName: cat.icon ?? "tag.fill").eliteBody().foregroundColor(c)
                                                }
                                                Text(cat.localizedName).eliteCaption().foregroundColor(sel ? c : .secondary).lineLimit(2).multilineTextAlignment(.center)
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
                                    TextField("Note", text: $note).autocorrectionDisabled().textFieldStyle(EliteTextFieldStyle())
                                }.padding(16)
                                Divider().padding(.leading, 48)
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar").foregroundColor(.secondary).frame(width: 20)
                                    DatePicker("", selection: $date, displayedComponents: .date).labelsHidden().datePickerStyle(.compact)
                                    Spacer()
                                }.padding(16)
                            }
                        }

                        Button(action: save) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .eliteFont(size: 16, weight: .semibold, textStyle: .body)
                                Text("Update Transaction")
                                    .eliteFont(size: 16, weight: .semibold, textStyle: .body)
                            }
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(AppTheme.accentGradient).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppTheme.baseColor.opacity(amount.isEmpty ? 0 : 0.25), radius: 8, y: 3)
                        }
                        .disabled(amount.isEmpty)
                        .opacity(amount.isEmpty ? 0.4 : 1)
                        .accessibilityLabel("Update Transaction")
                        .accessibilityAddTraits(.isButton)
                    }
                    .padding(16).padding(.bottom, 20)
                }
            }
            .navigationTitle("Edit Transaction").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppTheme.baseColor)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Done") { amountFocused = false }
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerView(selected: $selectedCurrency).presentationDetents([.medium])
            }
            .alert(
                Localizer.shared.l("recurring.alertTitle"),
                isPresented: $showRecurringAlert
            ) {
                Button(Localizer.shared.l("recurring.addReminder"), role: nil) {
                    addRecurringReminder()
                    dismiss()
                }
                Button(Localizer.shared.l("common.cancel"), role: .cancel) {
                    dismiss()
                }
            } message: {
                let typeLabel = selectedType == .income
                    ? Localizer.shared.l("transaction.income").lowercased()
                    : Localizer.shared.l("transaction.expense").lowercased()
                Text(Localizer.shared.l("recurring.alertMessage")
                    .replacingOccurrences(of: "{type}", with: typeLabel))
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

        Haptic.success()

        let vm          = transactionVM
        let txnId       = transaction.id
        let savedCur    = selectedCurrency
        let savedType   = selectedType
        let savedCat    = selectedCategory
        let savedNote   = note
        let savedDate   = date

        Task {
            await vm.updateTransaction(
                id: txnId, userId: uid, amount: v, currency: savedCur,
                type: savedType, categoryId: savedCat?.id, note: savedNote, date: savedDate,
                status: transaction.status, attachmentURL: transaction.attachmentURL)

            let isFutureDate = Calendar.current.startOfDay(for: savedDate) > Calendar.current.startOfDay(for: Date())
            let shouldAskRecurring = !isFutureDate

            if shouldAskRecurring {
                savedAmountForRecurring = v
                DispatchQueue.main.async {
                    showRecurringAlert = true
                }
            } else {
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }

    private func addRecurringReminder() {
        guard let uid = authVM.currentUserId else { return }
        let dayOfMonth = Calendar.current.component(.day, from: date)
        let amt = savedAmountForRecurring
        let cur = selectedCurrency
        let type = selectedType
        let cat = selectedCategory
        let title = cat?.name ?? note
        let vm = recurringVM

        Task {
            _ = await vm.add(
                userId: uid,
                title: title.isEmpty ? (type == .income ? "Gelir" : "Gider") : title,
                categoryId: cat?.id,
                transactionType: type,
                expectedAmount: amt,
                currency: cur,
                dayOfMonth: dayOfMonth
            )
        }
    }
}
