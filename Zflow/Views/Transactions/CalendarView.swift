import SwiftUI
import EventKit
import Combine

// MARK: - Calendar Manager (Apple Calendar permission + sync)

@MainActor
final class CalendarManager: ObservableObject {
    @Published var authStatus: EKAuthorizationStatus = .notDetermined
    @Published var appleEvents: [EKEvent] = []
    private let store = EKEventStore()

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authStatus = granted ? .fullAccess : .denied
            if granted { fetchAppleEvents() }
        } catch {
            authStatus = .denied
        }
    }

    func fetchAppleEvents() {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -1, to: Date()),
              let end   = cal.date(byAdding: .month, value: 3, to: Date()) else { return }
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        appleEvents = store.events(matching: pred)
    }

    func addEvent(title: String, amount: Double, currency: String,
                  date: Date, notes: String?) -> String? {
        guard authStatus == .fullAccess else { return nil }
        let event       = EKEvent(eventStore: store)
        event.title     = "💰 \(title) — \(amount.formattedCurrency(code: currency))"
        event.startDate = date
        event.endDate   = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
        event.notes     = notes
        event.calendar  = store.defaultCalendarForNewEvents
        try? store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    var isAuthorized: Bool { authStatus == .fullAccess }
}

// MARK: - Calendar View

struct CalendarView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var scheduledPaymentVM: ScheduledPaymentViewModel
    @StateObject private var calMgr = CalendarManager()
    @Environment(\.colorScheme) var scheme

    @State private var selectedDate   = Date()
    @State private var displayedMonth = Date()
    @State private var showAddEvent   = false
    @State private var showPermSheet  = false
    @State private var transactionToDelete: Transaction? = nil
    @State private var transactionToEdit: Transaction? = nil

    private var cal: Calendar { Calendar.current }

    private var txnForDate: [Transaction] {
        transactionVM.transactions.filter {
            guard let d = $0.date else { return false }
            return cal.isDate(d, inSameDayAs: selectedDate)
        }
    }

    private var readyPaymentsForDate: [ScheduledPayment] {
        scheduledPaymentVM.readyPayments.filter {
            cal.isDate($0.scheduledDate, inSameDayAs: selectedDate)
        }
    }

    private var pendingPaymentsForDate: [ScheduledPayment] {
        scheduledPaymentVM.pendingPayments.filter {
            cal.isDate($0.scheduledDate, inSameDayAs: selectedDate)
        }
    }

    private var monthDays: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let offset  = (weekday + 5) % 7   // Mon-start
        var days: [Date?] = Array(repeating: nil, count: offset)
        for d in range {
            if let date = cal.date(byAdding: .day, value: d - 1, to: first) { days.append(date) }
        }
        return days
    }

    private var monthIncome: Double {
        transactionVM.transactions
            .filter { guard let d = $0.date else { return false }
                return cal.isDate(d, equalTo: displayedMonth, toGranularity: .month)
                    && $0.type == "income" }
            .reduce(0) { $0 + transactionVM.convert($1) }
    }

    private var monthExpense: Double {
        transactionVM.transactions
            .filter { guard let d = $0.date else { return false }
                return cal.isDate(d, equalTo: displayedMonth, toGranularity: .month)
                    && $0.type == "expense" }
            .reduce(0) { $0 + transactionVM.convert($1) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        monthSummaryCard
                        calendarGrid
                        selectedDaySection
                        appleCalendarSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(L.calendarTitle.localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if calMgr.isAuthorized { showAddEvent = true }
                        else { showPermSheet = true }
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ZColor.indigo)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(ZColor.indigo.opacity(0.10)))
                    }
                    .padding(.trailing, 4)
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddCalendarEventView(defaultDate: selectedDate, calMgr: calMgr)
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
                    .environmentObject(scheduledPaymentVM)
            }
            .sheet(isPresented: $showPermSheet) {
                CalendarPermissionView {
                    Task { await calMgr.requestAccess() }
                    showPermSheet = false
                }
            }
            .sheet(item: $transactionToEdit) { txn in
                EditTransactionView(transaction: txn)
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
            .confirmationDialog(
                NSLocalizedString("common.delete", comment: "Delete"),
                isPresented: Binding(
                    get: { transactionToDelete != nil },
                    set: { if !$0 { transactionToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("common.delete", comment: "Delete"), role: .destructive) {
                    if let txn = transactionToDelete, let uid = authVM.currentUserId {
                        Task {
                            await transactionVM.deleteTransaction(id: txn.id, userId: uid)
                            Haptic.success()
                        }
                        transactionToDelete = nil
                    }
                }
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                    transactionToDelete = nil
                }
            } message: {
                Text(NSLocalizedString("common.deleteWarning", comment: "This action cannot be undone."))
            }
            .task { await calMgr.requestAccess() }
        }
    }

    // MARK: - Month Summary

    private var monthSummaryCard: some View {
        GradientCard(gradient: AppTheme.accentGradient) {
            VStack(spacing: 14) {
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        }
                        Haptic.selection()
                    } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8)).frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .accessibilityLabel("Previous month")

                    Spacer()

                    VStack(spacing: 2) {
                        Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("ZFlow Calendar")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        }
                        Haptic.selection()
                    } label: {
                        Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8)).frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .accessibilityLabel("Next month")
                }

                HStack(spacing: 0) {
                    summaryChip(label: NSLocalizedString("dashboard.income", comment: ""), amount: monthIncome, tint: Color(hex: "#86EFAC"))
                    Rectangle().fill(Color.white.opacity(0.2)).frame(width: 0.5, height: 36)
                    summaryChip(label: NSLocalizedString("dashboard.expense", comment: ""), amount: monthExpense, tint: Color(hex: "#FCA5A5"))
                }
                .padding(.horizontal, 10).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.12)))
            }
            .padding(16).frame(maxWidth: .infinity)
        }
    }

    private func summaryChip(label: String, amount: Double, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
            Text(amount.formattedShort(code: transactionVM.primaryCurrency))
                .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers (locale-aware, Mon-start)
            HStack(spacing: 0) {
                let symbols = {
                    let s = cal.shortWeekdaySymbols  // [Sun, Mon, Tue, ...]
                    return Array(s.dropFirst()) + [s[0]]  // [Mon, Tue, ..., Sun]
                }()
                ForEach(symbols, id: \.self) { day in
                    Text(day).font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ZColor.labelTert)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Days
            let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(14)
        .zFlowCard()
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday    = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let txns       = transactionVM.transactions.filter {
            guard let d = $0.date else { return false }
            return cal.isDate(d, inSameDayAs: date)
        }
        let hasIncome   = txns.contains { $0.type == "income" }
        let hasExpense  = txns.contains { $0.type == "expense" }
        let appleCount  = calMgr.appleEvents.filter { cal.isDate($0.startDate, inSameDayAs: date) }.count
        let hasPending  = scheduledPaymentVM.scheduledPayments.contains {
            ($0.status == "pending" || $0.status == "ready")
            && cal.isDate($0.scheduledDate, inSameDayAs: date)
        }

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selectedDate = date }
            Haptic.selection()
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundColor(
                        isSelected ? .white
                        : isToday ? ZColor.indigo
                        : ZColor.label)
                    .frame(width: 34, height: 34)
                    .background(
                        Group {
                            if isSelected {
                                Circle().fill(AppTheme.accentGradient)
                            } else if isToday {
                                Circle().strokeBorder(ZColor.indigo, lineWidth: 1.5)
                            } else {
                                Circle().fill(Color.clear)
                            }
                        }
                    )

                // Dot indicators
                HStack(spacing: 4) {
                    if hasIncome  { Circle().fill(ZColor.income).frame(width: 5, height: 5) }
                    if hasExpense { Circle().fill(ZColor.expense).frame(width: 5, height: 5) }
                    if appleCount > 0 { Circle().fill(ZColor.info).frame(width: 5, height: 5) }
                    if hasPending { Circle().fill(Color.orange).frame(width: 5, height: 5) }
                }
                .frame(height: 5)
            }
            .frame(height: 52)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected Day

    private var selectedDaySection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))

            // Pending Payments Warning (upcoming, not yet due)
            if !pendingPaymentsForDate.isEmpty {
                VStack(spacing: 8) {
                    ForEach(pendingPaymentsForDate, id: \.id) { payment in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yaklaşan Ödeme")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                                Text(payment.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ZColor.label)
                                Text(payment.amount.formattedCurrency(code: payment.currency))
                                    .font(.system(size: 13))
                                    .foregroundColor(ZColor.labelSec)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                )
            }

            // Ready Payments Section (Requires Approval)
            if !readyPaymentsForDate.isEmpty {
                VStack(spacing: 8) {
                    ForEach(readyPaymentsForDate, id: \.id) { payment in
                        ReadyPaymentCard(
                            payment: payment,
                            onApprove: {
                                Task {
                                    guard let userId = authVM.currentUserId else { return }
                                    let confirmed = await scheduledPaymentVM.confirmPayment(
                                        payment: payment,
                                        transactionVM: transactionVM,
                                        userId: userId
                                    )
                                    if confirmed { Haptic.success() }
                                }
                            },
                            onReject: {
                                Task {
                                    await scheduledPaymentVM.cancelPayment(paymentId: payment.id)
                                    Haptic.light()
                                }
                            }
                        )
                    }
                }
                .padding(12)
                .background(Color(UIColor.systemYellow).opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(UIColor.systemYellow).opacity(0.3), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Transactions for Date
            if txnForDate.isEmpty && readyPaymentsForDate.isEmpty && pendingPaymentsForDate.isEmpty {
                HStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(ZColor.labelTert)
                    Text(L.noEventsToday.localized)
                        .font(.system(size: 14)).foregroundColor(ZColor.labelSec)
                    Spacer()
                }
                .padding(16)
                .zFlowCard()
            } else if !txnForDate.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(txnForDate.enumerated()), id: \.element.id) { idx, txn in
                        TransactionRow(
                            transaction: txn,
                            category: transactionVM.category(for: txn.categoryId))
                        // Swipe only, no context menu
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                transactionToDelete = txn
                                Haptic.medium()
                            } label: {
                                Label(NSLocalizedString("common.delete", comment: "Delete"),
                                      systemImage: "trash.fill")
                            }
                            
                            Button {
                                transactionToEdit = txn
                                Haptic.light()
                            } label: {
                                Label(NSLocalizedString("common.edit", comment: "Edit"),
                                      systemImage: "pencil")
                            }
                            .tint(ZColor.indigo)
                        }
                        
                        if idx < txnForDate.count - 1 { Divider().padding(.leading, 70) }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5))
            }
        }
    }    // MARK: - Apple Calendar Section

    private var appleCalendarSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Apple Calendar")

            if !calMgr.isAuthorized {
                HStack(spacing: 12) {
                    Image(systemName: "calendar").font(.system(size: 20)).foregroundColor(ZColor.indigo)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(NSLocalizedString("calendar.syncTitle", comment: ""))
                            .font(.system(size: 14, weight: .semibold))
                        Text(NSLocalizedString("calendar.syncSubtitle", comment: ""))
                            .font(.system(size: 12)).foregroundColor(ZColor.labelSec)
                    }
                    Spacer()
                    Button(NSLocalizedString("calendar.enable", comment: "")) {
                        Task { await calMgr.requestAccess() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ZColor.indigo)
                }
                .padding(14).zFlowCard()
            } else {
                let dayEvents = calMgr.appleEvents.filter {
                    cal.isDate($0.startDate, inSameDayAs: selectedDate)
                }
                if dayEvents.isEmpty {
                    Text(NSLocalizedString("calendar.noAppleEvents", comment: ""))
                        .font(.system(size: 13)).foregroundColor(ZColor.labelSec)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).zFlowCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(dayEvents.enumerated()), id: \.element.eventIdentifier) { idx, event in
                            HStack(spacing: 12) {
                                Circle().fill(ZColor.info).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title ?? "Event")
                                        .font(.system(size: 14, weight: .medium))
                                    Text(event.startDate.formatted(.dateTime.hour().minute()))
                                        .font(.system(size: 12)).foregroundColor(ZColor.labelSec)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Color(.secondarySystemGroupedBackground))
                            if idx < dayEvents.count - 1 { Divider().padding(.leading, 34) }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5))
                }
            }
        }
    }
}

// MARK: - Calendar Permission View

struct CalendarPermissionView: View {
    var onEnable: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(AppTheme.accentGradient)
            Text(NSLocalizedString("calendar.permTitle", comment: ""))
                .font(.system(size: 24, weight: .bold))
            Text(L.calPermDesc.localized)
                .font(.system(size: 15)).foregroundColor(ZColor.labelSec)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { onEnable() } label: {
                Text(NSLocalizedString("calendar.enableAccess", comment: ""))
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.accentGradient))
            }
            .padding(.horizontal, 28)
            Button(NSLocalizedString("calendar.notNow", comment: "")) { dismiss() }
                .font(.system(size: 14)).foregroundColor(ZColor.labelSec)
            Spacer()
        }
    }
}

// MARK: - Add Calendar Event View

struct AddCalendarEventView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var scheduledPaymentVM: ScheduledPaymentViewModel
    @ObservedObject var calMgr: CalendarManager
    @Environment(\.dismiss) var dismiss

    let defaultDate: Date
    @State private var title    = ""
    @State private var amount   = ""
    @State private var currency: Currency = .try_
    @State private var eventDate: Date
    @State private var note     = ""
    @State private var selectedType = "expense"
    @State private var selectedCategory: UUID? = nil
    @State private var isSaving = false

    init(defaultDate: Date, calMgr: CalendarManager) {
        self.defaultDate = defaultDate
        self._eventDate  = State(initialValue: defaultDate)
        self.calMgr      = calMgr
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("calendar.event", comment: "")) {
                    TextField(NSLocalizedString("calendar.eventTitle", comment: ""), text: $title)
                    HStack {
                        TextField(NSLocalizedString("transaction.amount", comment: ""), text: $amount).keyboardType(.decimalPad)
                        Picker("", selection: $currency) {
                            ForEach(Currency.allCases) { c in Text("\(c.flag) \(c.rawValue)").tag(c) }
                        }.labelsHidden()
                    }
                    DatePicker(NSLocalizedString("calendar.dateTime", comment: ""), selection: $eventDate)
                }
                
                Section("Type") {
                    Picker("", selection: $selectedType) {
                        Text("Expense").tag("expense")
                        Text("Income").tag("income")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Category") {
                    Picker("Select Category", selection: $selectedCategory) {
                        Text("None").tag(UUID?(nil))
                        ForEach(transactionVM.categories) { cat in
                            Label {
                                Text(cat.name)
                            } icon: {
                                Image(systemName: cat.icon!)
                                    .foregroundColor(Color(hex: cat.color))
                            }
                            .tag(UUID?(cat.id))
                        }
                    }
                }
                
                Section(NSLocalizedString("transaction.note", comment: "")) {
                    TextField(NSLocalizedString("calendar.optionalNote", comment: ""), text: $note, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(NSLocalizedString("calendar.newEvent", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.cancel.localized) { dismiss() }.foregroundColor(ZColor.indigo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("calendar.add", comment: "")) {
                        saveScheduledPayment()
                    }
                    .disabled(title.isEmpty || isSaving)
                    .foregroundColor(ZColor.indigo)
                }
            }
        }
    }
    
    private func saveScheduledPayment() {
        guard let userId = authVM.currentUserId else { return }
        isSaving = true
        
        let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let transactionType = TransactionType(rawValue: selectedType) ?? .expense
        
        Task {
            // Create scheduled payment in database
            let success = await scheduledPaymentVM.addScheduledPayment(
                userId: userId,
                title: title,
                amount: amt,
                currency: currency,
                type: transactionType,
                categoryId: selectedCategory,
                note: note.isEmpty ? nil : note,
                scheduledDate: eventDate,
                calendarEventId: nil
            )
            
            if success {
                // Also add to Apple Calendar if authorized
                if calMgr.isAuthorized {
                    _ = calMgr.addEvent(
                        title: title,
                        amount: amt,
                        currency: currency.rawValue,
                        date: eventDate,
                        notes: note.isEmpty ? nil : note
                    )
                }
                Haptic.success()
                dismiss()
            }
            
            isSaving = false
        }
    }
}
