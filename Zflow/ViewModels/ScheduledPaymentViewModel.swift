//
//  ScheduledPaymentViewModel.swift
//  Zflow
//
//  Created by M.Sinan GÖKÇÜL on 1.03.2026.
//

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
    
    init() {
        startDailyCheck()
        requestNotificationPermission()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("📱 Notification permission granted")
            }
        }
    }
    
    private func startDailyCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { await self?.checkScheduledPayments() }
        }
        Task { await checkScheduledPayments() }
    }
    
    func checkScheduledPayments() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        let readyPayments = scheduledPayments.filter { payment in
            guard payment.status == ScheduledPaymentStatus.pending.rawValue,
                  let scheduledDay = cal.startOfDay(for: payment.scheduledDate) as Date? else {
                return false
            }
            return scheduledDay <= today
        }
        
        for payment in readyPayments {
            await updatePaymentStatus(paymentId: payment.id, status: .ready)
            sendPaymentNotification(payment: payment)
        }
    }
    
    private func sendPaymentNotification(payment: ScheduledPayment) {
        let content = UNMutableNotificationContent()
        content.title = "💰 Ödeme Hatırlatıcısı"
        content.body = "\(payment.title) için \(payment.amount.formattedCurrency(code: payment.currency)) ödeme günü geldi."
        content.sound = .default
        content.userInfo = ["paymentId": payment.id.uuidString]
        
        let request = UNNotificationRequest(identifier: payment.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    func fetchScheduledPayments(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data: [ScheduledPayment] = try await supabase
                .from("scheduled_payments")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("scheduled_date", ascending: true)
                .execute()
                .value
            
            scheduledPayments = data
            await checkScheduledPayments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
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
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func updatePaymentStatus(paymentId: UUID, status: ScheduledPaymentStatus) async {
        do {
            // AnyJSON kullanarak Supabase'e gönder
            if status == .completed {
                let updates = ["status": status.rawValue, "completed_at": Date().ISO8601Format()]
                try await supabase
                    .from("scheduled_payments")
                    .update(updates)
                    .eq("id", value: paymentId.uuidString)
                    .execute()
            } else {
                let updates = ["status": status.rawValue]
                try await supabase
                    .from("scheduled_payments")
                    .update(updates)
                    .eq("id", value: paymentId.uuidString)
                    .execute()
            }
            
            // Local state güncelle
            if let index = scheduledPayments.firstIndex(where: { $0.id == paymentId }) {
                scheduledPayments[index].status = status.rawValue
                if status == .completed { scheduledPayments[index].completedAt = Date() }
            }
        } catch {
            print("❌ Update error: \(error)")
        }
    }
    
    func confirmPayment(payment: ScheduledPayment, transactionVM: TransactionViewModel, userId: UUID) async -> Bool {
        let success = await transactionVM.addTransaction(
            userId: userId,
            amount: payment.amount,
            currency: Currency(rawValue: payment.currency) ?? .try_,
            type: TransactionType(rawValue: payment.type ?? "expense") ?? .expense,
            categoryId: payment.categoryId,
            note: payment.note,
            date: Date()
        )
        
        if success {
            await updatePaymentStatus(paymentId: payment.id, status: .completed)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [payment.id.uuidString])
        }
        return success
    }
    
    func cancelPayment(paymentId: UUID) async {
        await updatePaymentStatus(paymentId: paymentId, status: .cancelled)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [paymentId.uuidString])
    }
    
    func deletePayment(paymentId: UUID, userId: UUID) async {
        do {
            try await supabase
                .from("scheduled_payments")
                .delete()
                .eq("id", value: paymentId.uuidString)
                .execute()
            
            scheduledPayments.removeAll { $0.id == paymentId }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [paymentId.uuidString])
        } catch {
            print("❌ Delete error: \(error)")
        }
    }
    
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
