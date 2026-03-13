import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class FamilyViewModel: ObservableObject {
    @Published var members: [FamilyMember] = []
    @Published var family: Family?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Family Actions
    
    func fetchFamilyInfo(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Get user profile to find family_id
            let profile: Profile = try await supabase.from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            guard let familyId = profile.familyId else {
                self.family = nil
                self.members = []
                isLoading = false
                return
            }
            
            // 2. Fetch Family details
            let familyInfo: Family = try await supabase.from("families")
                .select()
                .eq("id", value: familyId.uuidString)
                .single()
                .execute()
                .value
            self.family = familyInfo
            
            // 3. Fetch Family Members (joining with profiles to get display names/avatars)
            // Using a RPC or raw query if join is complex, but here we can just fetch members
            // For simplicity, let's assume 'family_members' table exists or we query profiles with familyId
            let membersList: [Profile] = try await supabase.from("profiles")
                .select()
                .eq("family_id", value: familyId.uuidString)
                .execute()
                .value
            
            self.members = membersList.map { p in
                FamilyMember(
                    id: p.id,
                    userId: p.id,
                    displayName: p.fullName,
                    avatarURL: p.avatarURL,
                    role: p.familyRole ?? (p.id == familyInfo.adminId ? "admin" : "member"),
                    status: p.familyStatus ?? "active",
                    relationship: p.familyRelationship
                )
            }
        } catch {
            print("❌ [FamilyVM] Fetch error: \(error)")
            // If family doesn't exist yet, it's not necessarily an error to show the user
        }
        isLoading = false
    }
    
    func createFamily(name: String, adminId: UUID) async {
        isLoading = true
        do {
            // 1. Create family record
            let familyId = UUID()
            let familyInsert = ["id": familyId.uuidString, "name": name, "admin_id": adminId.uuidString]
            try await supabase.from("families").insert(familyInsert).execute()
            
            // 2. Update admin profile with family_id
            try await supabase.from("profiles")
                .update([
                    "family_id": familyId.uuidString,
                    "family_role": "admin",
                    "family_status": "active"
                ])
                .eq("id", value: adminId.uuidString)
                .execute()
            
            await fetchFamilyInfo(userId: adminId)
            Haptic.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptic.error()
        }
        isLoading = false
    }
    
    func sendInvite(email: String, inviterId: UUID) async -> Bool {
        // This usually goes through a backend function to handle security and email sending
        do {
            guard let url = URL(string: "\(AppConstants.serverURL)/api/family/invite") else { return false }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "email": email,
                "inviter_id": inviterId.uuidString
            ])
            
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return false
            }
            Haptic.success()
            return true
        } catch {
            return false
        }
    }

    func joinFamily(familyId: String, userId: UUID) async -> Bool {
        isLoading = true
        do {
            // Update user profile with pending status
            try await supabase.from("profiles")
                .update([
                    "family_id": familyId,
                    "family_status": "pending",
                    "family_role": "member"
                ])
                .eq("id", value: userId.uuidString)
                .execute()
            
            await fetchFamilyInfo(userId: userId)
            Haptic.success()
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptic.error()
            isLoading = false
            return false
        }
    }

    func approveMember(memberId: UUID, adminId: UUID) async {
        do {
            try await supabase.from("profiles")
                .update(["family_status": "active"])
                .eq("id", value: memberId.uuidString)
                .execute()
            await fetchFamilyInfo(userId: adminId)
            Haptic.success()
        } catch {
            print("❌ Approval error: \(error)")
            Haptic.error()
        }
    }

    func rejectMember(memberId: UUID, adminId: UUID) async {
        do {
            try await supabase.from("profiles")
                .update([
                    "family_id": nil as String?,
                    "family_status": nil as String?,
                    "family_role": nil as String?,
                    "family_relationship": nil as String?
                ])
                .eq("id", value: memberId.uuidString)
                .execute()
            await fetchFamilyInfo(userId: adminId)
            Haptic.success()
        } catch {
            print("❌ Rejection error: \(error)")
            Haptic.error()
        }
    }

    func updateMemberSettings(memberId: UUID, adminId: UUID, role: String, relationship: String) async {
        do {
            try await supabase.from("profiles")
                .update([
                    "family_role": role,
                    "family_relationship": relationship
                ])
                .eq("id", value: memberId.uuidString)
                .execute()
            await fetchFamilyInfo(userId: adminId)
            Haptic.success()
        } catch {
            print("❌ Update error: \(error)")
            Haptic.error()
        }
    }

    func leaveFamily(userId: UUID) async {
        isLoading = true
        do {
            try await supabase.from("profiles")
                .update([
                    "family_id": nil as String?,
                    "family_status": nil as String?,
                    "family_role": nil as String?,
                    "family_relationship": nil as String?
                ])
                .eq("id", value: userId.uuidString)
                .execute()
            
            self.family = nil
            self.members = []
            Haptic.success()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Leave error: \(error)")
            Haptic.error()
        }
        isLoading = false
    }

    func removeMember(memberId: UUID, adminId: UUID) async {
        do {
            try await supabase.from("profiles")
                .update([
                    "family_id": nil as String?,
                    "family_status": nil as String?,
                    "family_role": nil as String?,
                    "family_relationship": nil as String?
                ])
                .eq("id", value: memberId.uuidString)
                .execute()
            await fetchFamilyInfo(userId: adminId)
            Haptic.success()
        } catch {
            print("❌ Remove member error: \(error)")
            Haptic.error()
        }
    }

    func renameFamilyName(familyId: UUID, adminId: UUID, newName: String) async {
        do {
            try await supabase.from("families")
                .update(["name": newName])
                .eq("id", value: familyId.uuidString)
                .execute()
            await fetchFamilyInfo(userId: adminId)
            Haptic.success()
        } catch {
            print("❌ Rename family error: \(error)")
            Haptic.error()
        }
    }

    func updateFamilySettings(familyId: UUID, adminId: UUID, name: String, colorHex: String) async {
        do {
            try await supabase.from("families")
                .update([
                    "name": name,
                    "card_color": colorHex
                ])
                .eq("id", value: familyId.uuidString)
                .execute()
            await fetchFamilyInfo(userId: adminId)
            Haptic.success()
        } catch {
            print("❌ Family update error: \(error)")
            Haptic.error()
        }
    }
}
