//
//  RecurringNotificationManager.swift
//  Zflow
//
//  Düzenli işlemler (recurring_transactions) için
//  UNCalendarNotificationTrigger tabanlı tekrarlayan bildirimler.
//
//  GİDER: 2 gün önce (hazırlık) + ödeme günü sabahı (aksiyon)
//  GELİR: Sadece ödeme günü sabahı (müjde)
//

import Foundation
import UserNotifications

struct RecurringNotificationManager {

    private static let center = UNUserNotificationCenter.current()

    // MARK: - Public API

    /// Belirli bir recurring_transaction için tekrarlayan bildirimleri zamanlar.
    /// Eski bildirimleri siler, yenilerini kurar.
    static func schedule(
        id: UUID,
        title: String,
        amount: Double?,
        currency: String,
        transactionType: String, // "income" | "expense"
        dayOfMonth: Int
    ) {
        // Önce eski bildirimleri temizle
        removeNotifications(for: id)

        let amountStr = formatAmount(amount, currency: currency)

        if transactionType == "expense" {
            // ── GİDER: 2 gün önce (Hazırlık) ──
            scheduleExpenseReminder(
                id: id, title: title,
                amountStr: amountStr, dayOfMonth: dayOfMonth
            )
            // ── GİDER: Ödeme günü sabahı (Aksiyon) ──
            scheduleExpenseDueDay(
                id: id, title: title,
                amountStr: amountStr, dayOfMonth: dayOfMonth
            )
        } else {
            // ── GELİR: Sadece ödeme günü sabahı (Müjde) ──
            scheduleIncomeDay(
                id: id, title: title,
                amountStr: amountStr, dayOfMonth: dayOfMonth
            )
        }
    }

    /// Bir recurring_transaction'ın tüm bildirimlerini kaldırır.
    static func removeNotifications(for id: UUID) {
        let identifiers = [
            "recurring-prep-\(id.uuidString)",
            "recurring-due-\(id.uuidString)",
            "recurring-income-\(id.uuidString)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// Tüm aktif recurring_transactions için bildirimleri yeniden zamanlar.
    static func rescheduleAll(_ items: [RecurringTransaction]) {
        // Önce tüm recurring bildirimlerini temizle
        center.getPendingNotificationRequests { requests in
            let recurringIds = requests
                .filter { $0.identifier.hasPrefix("recurring-") }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: recurringIds)
        }

        for item in items where item.isActive {
            schedule(
                id: item.id,
                title: item.title,
                amount: item.expectedAmount,
                currency: item.currency,
                transactionType: item.transactionType,
                dayOfMonth: item.dayOfMonth
            )
        }
    }

    // MARK: - Private: Expense Notifications

    /// GİDER — 2 gün önce, saat 09:00 (tekrarlayan, her ay)
    private static func scheduleExpenseReminder(
        id: UUID, title: String,
        amountStr: String, dayOfMonth: Int
    ) {
        let reminderDay = adjustedDay(dayOfMonth, offset: -2)

        var comps = DateComponents()
        comps.day = reminderDay
        comps.hour = 9
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "📋 Hazırlık: \(title)"
        content.body = "2 gün sonra \(amountStr) tutarında ödemeniz var. Hazırlıklı olun!"
        content.sound = .default
        content.categoryIdentifier = "RECURRING_REMINDER"
        content.userInfo = [
            "recurringId": id.uuidString,
            "type": "expense_prep"
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "recurring-prep-\(id.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error { print("❌ Recurring prep notification error: \(error)") }
        }
    }

    /// GİDER — Ödeme günü, saat 08:00 (tekrarlayan, her ay)
    private static func scheduleExpenseDueDay(
        id: UUID, title: String,
        amountStr: String, dayOfMonth: Int
    ) {
        var comps = DateComponents()
        comps.day = dayOfMonth
        comps.hour = 8
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "💳 Ödeme Günü: \(title)"
        content.body = "Bugün \(amountStr) tutarında ödemeniz var. Ödemeyi yapmayı unutmayın!"
        content.sound = .default
        content.categoryIdentifier = "RECURRING_DUE"
        content.userInfo = [
            "recurringId": id.uuidString,
            "type": "expense_due"
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "recurring-due-\(id.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error { print("❌ Recurring due notification error: \(error)") }
        }
    }

    // MARK: - Private: Income Notification

    /// GELİR — Ödeme günü, saat 08:00 (tekrarlayan, her ay)
    private static func scheduleIncomeDay(
        id: UUID, title: String,
        amountStr: String, dayOfMonth: Int
    ) {
        var comps = DateComponents()
        comps.day = dayOfMonth
        comps.hour = 8
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "💸 Gelir Günü: \(title)"
        content.body = "Bugün \(amountStr) tutarında gelir bekleniyor. Harika bir gün!"
        content.sound = .default
        content.categoryIdentifier = "RECURRING_INCOME"
        content.userInfo = [
            "recurringId": id.uuidString,
            "type": "income_day"
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "recurring-income-\(id.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error { print("❌ Recurring income notification error: \(error)") }
        }
    }

    // MARK: - Helpers

    /// Ay günü offset uygular (Örn: 3. gün - 2 = 1. gün; 1. gün - 2 = 29. gün önceki ay)
    private static func adjustedDay(_ day: Int, offset: Int) -> Int {
        let adjusted = day + offset
        if adjusted < 1 { return adjusted + 30 } // Yaklaşık: önceki ayın sonuna sar
        if adjusted > 28 { return min(adjusted, 28) } // Güvenli sınır
        return adjusted
    }

    private static func formatAmount(_ amount: Double?, currency: String) -> String {
        guard let amount = amount else {
            return NSLocalizedString("recurring.variableAmount", comment: "Variable")
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}
