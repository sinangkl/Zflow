//
//  RecurringTransactionViewModel.swift
//  Zflow
//
//  Düzenli İşlem (recurring_transactions) CRUD ve bildirim yönetimi.
//

import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
final class RecurringTransactionViewModel: ObservableObject {

    @Published var recurringTransactions: [RecurringTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared.client
    private var cancellables: Set<AnyCancellable> = []

    init() {
        NotificationCenter.default
            .publisher(for: Notification.Name("ZFlowDidLogout"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.clearData() }
            .store(in: &cancellables)
    }
    
    func clearData() {
        recurringTransactions.removeAll()
        errorMessage = nil
    }

    // MARK: - Fetch

    func fetchAll(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data: [RecurringTransaction] = try await supabase
                .from("recurring_transactions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("day_of_month", ascending: true)
                .execute()
                .value

            recurringTransactions = data

            // Aktif olanların bildirimlerini zamanla
            RecurringNotificationManager.rescheduleAll(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add

    func add(
        userId: UUID,
        title: String,
        categoryId: UUID?,
        transactionType: TransactionType,
        expectedAmount: Double?,
        currency: Currency,
        dayOfMonth: Int
    ) async -> Bool {
        let insert = RecurringTransactionInsert(
            userId: userId,
            title: title,
            categoryId: categoryId,
            transactionType: transactionType.rawValue,
            expectedAmount: expectedAmount,
            currency: currency.rawValue,
            dayOfMonth: dayOfMonth,
            isActive: true
        )

        do {
            let saved: RecurringTransaction = try await supabase
                .from("recurring_transactions")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            recurringTransactions.append(saved)
            recurringTransactions.sort { $0.dayOfMonth < $1.dayOfMonth }

            // Bildirimleri zamanla
            RecurringNotificationManager.schedule(
                id: saved.id,
                title: saved.title,
                amount: saved.expectedAmount,
                currency: saved.currency,
                transactionType: saved.transactionType,
                dayOfMonth: saved.dayOfMonth
            )

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Toggle Active

    func toggleActive(id: UUID, isActive: Bool) async {
        do {
            try await supabase
                .from("recurring_transactions")
                .update(["is_active": isActive])
                .eq("id", value: id.uuidString)
                .execute()

            if let idx = recurringTransactions.firstIndex(where: { $0.id == id }) {
                recurringTransactions[idx].isActive = isActive

                if isActive {
                    let rt = recurringTransactions[idx]
                    RecurringNotificationManager.schedule(
                        id: rt.id, title: rt.title,
                        amount: rt.expectedAmount, currency: rt.currency,
                        transactionType: rt.transactionType,
                        dayOfMonth: rt.dayOfMonth
                    )
                } else {
                    RecurringNotificationManager.removeNotifications(for: id)
                }
            }
        } catch {
            print("❌ Toggle recurring error: \(error)")
        }
    }

    // MARK: - Update existing recurring

    func update(
        id: UUID,
        title: String,
        categoryId: UUID?,
        transactionType: TransactionType,
        expectedAmount: Double?,
        currency: Currency,
        dayOfMonth: Int,
        isActive: Bool
    ) async {
        do {
            let payload = RecurringTransactionUpdate(
                title: title,
                categoryId: categoryId,
                transactionType: transactionType.rawValue,
                expectedAmount: expectedAmount,
                currency: currency.rawValue,
                dayOfMonth: dayOfMonth,
                isActive: isActive
            )

            let updated: [RecurringTransaction] = try await supabase
                .from("recurring_transactions")
                .update(payload)
                .eq("id", value: id.uuidString)
                .select()
                .execute()
                .value

            if let fresh = updated.first,
               let idx = recurringTransactions.firstIndex(where: { $0.id == id }) {
                recurringTransactions[idx] = fresh
            }

            // Bildirimleri yeniden kur
            if isActive {
                if let rt = recurringTransactions.first(where: { $0.id == id }) {
                    RecurringNotificationManager.schedule(
                        id: rt.id,
                        title: rt.title,
                        amount: rt.expectedAmount,
                        currency: rt.currency,
                        transactionType: rt.transactionType,
                        dayOfMonth: rt.dayOfMonth
                    )
                }
            } else {
                RecurringNotificationManager.removeNotifications(for: id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func delete(id: UUID) async {
        do {
            try await supabase
                .from("recurring_transactions")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            recurringTransactions.removeAll { $0.id == id }
            RecurringNotificationManager.removeNotifications(for: id)
        } catch {
            print("❌ Delete recurring error: \(error)")
        }
    }

    // MARK: - Computed

    var activeTransactions: [RecurringTransaction] {
        recurringTransactions.filter(\.isActive)
    }

    var totalMonthlyIncome: Double {
        activeTransactions
            .filter { $0.transactionType == "income" }
            .reduce(0) { $0 + ($1.expectedAmount ?? 0) }
    }

    var totalMonthlyExpense: Double {
        activeTransactions
            .filter { $0.transactionType == "expense" }
            .reduce(0) { $0 + ($1.expectedAmount ?? 0) }
    }

    /// Yaklaşan (bugünden itibaren en yakın) düzenli işlemler
    var upcomingTransactions: [RecurringTransaction] {
        activeTransactions.sorted { $0.daysUntilNext < $1.daysUntilNext }
    }
}
