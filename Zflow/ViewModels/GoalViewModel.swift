// ============================================================
// ZFlow — GoalViewModel
// ============================================================

import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

// MARK: - Model

struct Goal: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: UUID?
    var familyId: UUID?
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date?
    var icon: String
    var colorHex: String
    var createdAt: Date?

    var percentage: Double {
        guard targetAmount > 0 else { return 0 }
        return min((currentAmount / targetAmount) * 100, 100)
    }

    var remaining: Double { max(targetAmount - currentAmount, 0) }
    var isComplete: Bool { currentAmount >= targetAmount }

    enum CodingKeys: String, CodingKey {
        case id, title, icon, deadline
        case userId       = "user_id"
        case familyId     = "family_id"
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case colorHex     = "color_hex"
        case createdAt    = "created_at"
    }
}

struct GoalInsert: Encodable {
    let userId: UUID?
    let familyId: UUID?
    let title: String
    let targetAmount: Double
    let currentAmount: Double
    let deadline: Date?
    let icon: String
    let colorHex: String

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case familyId     = "family_id"
        case title
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case deadline
        case icon
        case colorHex     = "color_hex"
    }
}

// MARK: - ViewModel

@MainActor
final class GoalViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(clearData),
            name: Notification.Name("ZFlowDidLogout"), object: nil
        )
    }

    @objc func clearData() { goals = [] }

    func fetchGoals(userId: UUID, familyId: UUID? = nil) async {
        isLoading = true
        do {
            var query = supabase.from("goals").select()
            
            if let fid = familyId {
                // Fetch goals belonging to either the user or their family
                query = query.or("user_id.eq.\(userId.uuidString),family_id.eq.\(fid.uuidString)")
            } else {
                query = query.eq("user_id", value: userId.uuidString)
            }
            
            let result: [Goal] = try await query
                .order("created_at", ascending: false)
                .execute()
                .value
            goals = result
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func addGoal(userId: UUID, title: String, target: Double, icon: String, color: String, deadline: Date?) async {
        let insert = GoalInsert(
            userId: userId, familyId: nil, title: title, targetAmount: target,
            currentAmount: 0, deadline: deadline, icon: icon, colorHex: color
        )
        do {
            try await supabase.from("goals").insert(insert).execute()
            await fetchGoals(userId: userId)
            Haptic.success()
        } catch { errorMessage = error.localizedDescription; Haptic.error() }
    }

    func contribute(goal: Goal, amount: Double, userId: UUID) async {
        let newAmount = min(goal.currentAmount + amount, goal.targetAmount)
        do {
            try await supabase.from("goals")
                .update(["current_amount": newAmount])
                .eq("id", value: goal.id.uuidString)
                .execute()
            await fetchGoals(userId: userId)
            Haptic.success()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteGoal(id: UUID, userId: UUID) async {
        do {
            try await supabase.from("goals").delete().eq("id", value: id.uuidString).execute()
            await fetchGoals(userId: userId)
        } catch { errorMessage = error.localizedDescription }
    }
}
