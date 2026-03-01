import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn  = false
    @Published var isLoading   = false
    @Published var errorMessage: String?
    @Published var currentUserId: UUID?
    @Published var userProfile: Profile?
    @Published var userAvatarData: Data?   // In-memory cached avatar

    @AppStorage("rememberMe") var rememberMe: Bool = true

    private let supabase = SupabaseManager.shared.client

    init() {
        Task { await checkSession(); listenAuthChanges() }
    }

    // MARK: - Session

    func checkSession() async {
        if !rememberMe { await signOut(); return }
        do {
            let session = try await supabase.auth.session
            currentUserId = session.user.id
            isLoggedIn    = true
            await fetchProfile()
        } catch {
            isLoggedIn    = false
            currentUserId = nil
        }
    }

    private func listenAuthChanges() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn:
                    currentUserId = session?.user.id
                    isLoggedIn    = true
                    await fetchProfile()
                case .signedOut:
                    currentUserId = nil
                    userProfile   = nil
                    isLoggedIn    = false
                default: break
                }
            }
        }
    }

    // MARK: - Auth Actions

    func signIn(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        do {
            let s = try await supabase.auth.signIn(email: email, password: password)
            currentUserId = s.user.id
            isLoggedIn    = true
            await fetchProfile()
            Haptic.success()
        } catch {
            errorMessage = friendlyError(error)
            Haptic.error()
        }
        isLoading = false
    }

    func signUp(email: String, password: String, fullName: String,
                userType: UserType, businessName: String? = nil) async {
        isLoading = true; errorMessage = nil
        do {
            let auth   = try await supabase.auth.signUp(email: email, password: password)
            let userId = auth.user.id

            let bName: String? = (userType == .business)
                ? (businessName?.trimmingCharacters(in: .whitespaces).isEmpty == false ? businessName : nil)
                : nil

            let profileInsert = ProfileInsert(
                id: userId,
                fullName: fullName,
                userType: userType.rawValue,
                businessName: bName,
                avatarURL: nil
            )

            try await supabase.from("profiles")
                .insert(profileInsert)
                .execute()

            await seedCategories(userId: userId, userType: userType.rawValue)

            currentUserId = userId
            isLoggedIn    = true
            await fetchProfile()
            Haptic.success()
        } catch {
            errorMessage = friendlyError(error)
            Haptic.error()
        }
        isLoading = false
    }

    // MARK: - Avatar

    func uploadAvatar(data: Data) async {
        guard let uid = currentUserId else { return }
        let path = "avatars/\(uid.uuidString).jpg"
        do {
            try await supabase.storage
                .from("avatars")
                .upload(path, data: data, options: FileOptions(upsert: true))

            // Update profile avatar_url
            let url = try await supabase.storage.from("avatars").createSignedURL(path: path, expiresIn: 60 * 60 * 24 * 7)

            try await supabase.from("profiles")
                .update(["avatar_url": url.absoluteString])
                .eq("id", value: uid.uuidString)
                .execute()

            await MainActor.run { self.userAvatarData = data }
            await fetchProfile()
        } catch { print("Avatar upload error: \(error)") }
    }

    func loadAvatar() async {
        guard let avatarURL = userProfile?.avatarURL,
              let url = URL(string: avatarURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run { self.userAvatarData = data }
        } catch { print("Avatar load error: \(error)") }
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch { errorMessage = error.localizedDescription }
        isLoggedIn    = false
        currentUserId = nil
        userProfile   = nil
        userAvatarData = nil
    }

    func fetchProfile() async {
        guard let uid = currentUserId else { return }
        do {
            let p: Profile = try await supabase.from("profiles")
                .select().eq("id", value: uid.uuidString).single().execute().value
            userProfile = p
            print("✅ [Profile] Fetched: fullName=\(p.fullName ?? "nil"), userType=\(p.userType ?? "nil"), businessName=\(p.businessName ?? "nil")")
            await loadAvatar()
        } catch {
            print("❌ [Profile] FETCH ERROR: \(error)")
            // Fallback: bir hata olsa bile mevcut profili koruyalım
        }
    }

    func updateProfile(fullName: String, businessName: String?) async -> Bool {
        guard let uid = currentUserId else { return false }
        do {
            var updates: [String: String] = ["full_name": fullName]
            if let bn = businessName { updates["business_name"] = bn }

            try await supabase.from("profiles")
                .update(updates).eq("id", value: uid.uuidString).execute()

            await fetchProfile()
            Haptic.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptic.error()
            return false
        }
    }

    // MARK: - Private

    private func seedCategories(userId: UUID, userType: String) async {
        let inserts = filteredDefaultCategories(for: userType).map {
            CategoryInsert(userId: userId, name: $0.name, color: $0.color, icon: $0.icon, type: $0.type)
        }
        print("🔐 [Auth] Seeding \(inserts.count) categories for userType: \(userType), userId: \(userId.uuidString)")
        do {
            try await supabase.from("categories").insert(inserts).execute()
            print("🔐 [Auth] Seed categories SUCCESS")
        } catch {
            print("❌ [Auth] SEED CATEGORIES ERROR: \(error)")
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("invalid login") || msg.contains("invalid credentials") {
            return "Incorrect email or password."
        }
        if msg.contains("already registered") || msg.contains("already exists") {
            return "An account with this email already exists."
        }
        if msg.contains("network") || msg.contains("connection") {
            return "Network error. Please check your connection."
        }
        return error.localizedDescription
    }
}
