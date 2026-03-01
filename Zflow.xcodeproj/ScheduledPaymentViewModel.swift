import SwiftUI
import Combine
import Supabase
import UserNotifications

@MainActor
final class ScheduledPaymentViewModel: ObservableObject {
    
    @Published var scheduledPayments: [ScheduledPayment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    private var timer: Timer?
    
    // MARK: - Init & Cleanup
    
    init() {
        startDailyCheck()
        requestNotificationPermission()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Notification Permission
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("📱 Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
    }
    
    // MARK: - Daily Check Timer
    
    private func startDailyCheck() {
        // Her saat kontrol et
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { await self?.checkScheduledPayments() }
        }
        // İlk açılışta da kontrol et
        Task { await checkScheduledPayments() }
    }
    
    // MARK: - Check Scheduled Payments
    
    func checkScheduledPayments() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        // Bugün veya önceki tarihlerde olan ve pending durumda olan ödemeleri bul
        let readyPayments = scheduledPayments.filter { payment in
            guard payment.status == ScheduledPaymentStatus.pending.rawValue,
                  let scheduledDay = cal.startOfDay(for: payment.scheduledDate) as Date? else {
                return false
            }
            return scheduledDay <= today
        }
        
        // Durumlarını "ready" olarak güncelle ve bildirim gönder
        for payment in readyPayments {
            await updatePaymentStatus(paymentId: payment.id, status: .ready)
            sendPaymentNotification(payment: payment)
        }
    }
    
    // MARK: - Send Notification
    
    private func sendPaymentNotification(payment: ScheduledPayment) {
        let content = UNMutableNotificationContent()
        content.title = "💰 Ödeme Hatırlatıcısı"
        content.body = "\(payment.title) için \(payment.amount.formattedCurrency(code: payment.currency)) ödeme günü geldi. Ödemeyi gerçekleştirdiniz mi?"
        content.sound = .default
        content.categoryIdentifier = "PAYMENT_CONFIRMATION"
        content.userInfo = ["paymentId": payment.id.uuidString]
        
        let request = UNNotificationRequest(
            identifier: payment.id.uuidString,
            content: content,
            trigger: nil // Hemen gönder
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Fetch Scheduled Payments
    
    func fetchScheduledPayments(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data: [ScheduledPayment] = try await supabase
                .from("scheduled_payments")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("scheduled_date", ascending: true)
                .execute()
                .value
            
            scheduledPayments = data
            
            // Fetch sonrası kontrol yap
            await checkScheduledPayments()
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Fetch scheduled payments error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Add Scheduled Payment
    
    func addScheduledPayment(
        userId: UUID,
        title: String,
        amount: Double,
        currency: Currency,
        type: TransactionType,
        categoryId: UUID?,
        note: String?,
        scheduledDate: Date,
        calendarEventId: String?
    ) async -> Bool {
        
        let insert = ScheduledPaymentInsert(
            userId: userId,
            title: title,
            amount: amount,
            currency: currency.rawValue,
            type: type.rawValue,
            categoryId: categoryId,
            note: note,
            scheduledDate: scheduledDate,
            status: ScheduledPaymentStatus.pending.rawValue,
            calendarEventId: calendarEventId
        )
        
        do {
            let _: ScheduledPayment = try await supabase
                .from("scheduled_payments")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
            
            await fetchScheduledPayments(userId: userId)
            
            // Gelecekteki ödeme için bildirim planla
            schedulePaymentReminder(
                paymentId: UUID(),
                title: title,
                amount: amount,
                currency: currency.rawValue,
                date: scheduledDate
            )
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Add scheduled payment error: \(error)")
            return false
        }
    }
    
    // MARK: - Schedule Future Notification
    
    private func schedulePaymentReminder(
        paymentId: UUID,
        title: String,
        amount: Double,
        currency: String,
        date: Date
    ) {
        // Sadece gelecekteki tarihler için bildirim planla
        guard date > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "💰 Ödeme Hatırlatıcısı"
        content.body = "\(title) için \(amount.formattedCurrency(code: currency)) ödeme günü geldi!"
        content.sound = .default
        content.categoryIdentifier = "PAYMENT_CONFIRMATION"
        content.userInfo = ["paymentId": paymentId.uuidString]
        
        // Tarihi gün başlangıcına ayarla ve saat 09:00'a planla
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: paymentId.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Scheduled notification error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Update Payment Status
    
    func updatePaymentStatus(paymentId: UUID, status: ScheduledPaymentStatus) async {
        do {
            var updates: [String: Any] = ["status": status.rawValue]
            
            if status == .completed {
                updates["completed_at"] = Date()
            }
            
            try await supabase
                .from("scheduled_payments")
                .update(updates)
                .eq("id", value: paymentId.uuidString)
                .execute()
            
            // Listeden güncelle
            if let index = scheduledPayments.firstIndex(where: { $0.id == paymentId }) {
                var updated = scheduledPayments[index]
                updated.status = status.rawValue
                if status == .completed {
                    updated.completedAt = Date()
                }
                scheduledPayments[index] = updated
            }
            
        } catch {
            print("❌ Update payment status error: \(error)")
        }
    }
    
    // MARK: - Confirm Payment (Create Transaction)
    
    func confirmPayment(
        payment: ScheduledPayment,
        transactionVM: TransactionViewModel,
        userId: UUID
    ) async -> Bool {
        
        // Transaction oluştur
        let success = await transactionVM.addTransaction(
            userId: userId,
            amount: payment.amount,
            currency: Currency(rawValue: payment.currency) ?? .try_,
            type: TransactionType(rawValue: payment.type ?? "expense") ?? .expense,
            categoryId: payment.categoryId,
            note: payment.note,
            date: Date() // Bugünün tarihi
        )
        
        if success {
            // Ödeme durumunu completed yap
            await updatePaymentStatus(paymentId: payment.id, status: .completed)
            
            // Bildirimi temizle
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [payment.id.uuidString])
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [payment.id.uuidString])
            
            return true
        }
        
        return false
    }
    
    // MARK: - Cancel Payment
    
    func cancelPayment(paymentId: UUID) async {
        await updatePaymentStatus(paymentId: paymentId, status: .cancelled)
        
        // Bildirimi iptal et
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [paymentId.uuidString])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [paymentId.uuidString])
    }
    
    // MARK: - Delete Payment
    
    func deletePayment(paymentId: UUID, userId: UUID) async {
        do {
            try await supabase
                .from("scheduled_payments")
                .delete()
                .eq("id", value: paymentId.uuidString)
                .execute()
            
            scheduledPayments.removeAll { $0.id == paymentId }
            
            // Bildirimi iptal et
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [paymentId.uuidString])
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [paymentId.uuidString])
            
        } catch {
            print("❌ Delete payment error: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    var pendingPayments: [ScheduledPayment] {
        scheduledPayments.filter { $0.status == ScheduledPaymentStatus.pending.rawValue }
    }
    
    var readyPayments: [ScheduledPayment] {
        scheduledPayments.filter { $0.status == ScheduledPaymentStatus.ready.rawValue }
    }
    
    var completedPayments: [ScheduledPayment] {
        scheduledPayments.filter { $0.status == ScheduledPaymentStatus.completed.rawValue }
    }
}
