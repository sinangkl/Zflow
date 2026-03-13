import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
final class FamilyActivityViewModel: ObservableObject {
    @Published var activities: [FamilyActivity] = []
    @Published var isLoading = false
    
    private let supabase = SupabaseManager.shared.client
    
    func fetchActivities(familyId: UUID) async {
        isLoading = true
        do {
            let result: [FamilyActivity] = try await supabase
                .from("family_activities")
                .select()
                .eq("family_id", value: familyId.uuidString)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            self.activities = result
        } catch {
            print("❌ [ActivityVM] Fetch error: \(error)")
        }
        isLoading = false
    }
    
    struct FamilyActivityInsert: Encodable {
        let familyId: UUID
        let userId: UUID
        let actionType: String
        let details: [String: String]?

        enum CodingKeys: String, CodingKey {
            case familyId = "family_id"
            case userId = "user_id"
            case actionType = "action_type"
            case details
        }
    }
    
    func logActivity(familyId: UUID, userId: UUID, type: String, details: [String: String]? = nil) async {
        let insert = FamilyActivityInsert(
            familyId: familyId,
            userId: userId,
            actionType: type,
            details: details
        )
        
        _ = try? await supabase.from("family_activities").insert(insert).execute()
        await fetchActivities(familyId: familyId)
    }
}
