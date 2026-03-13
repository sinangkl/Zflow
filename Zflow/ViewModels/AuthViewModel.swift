import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST
import GoogleSignIn
import UIKit
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn  = false
    @Published var isLoading   = false
    @Published var errorMessage: String?
    @Published var currentUserId: UUID?
    @Published var currentUserEmail: String?
    @Published var userProfile: Profile?
    @Published var userAvatarData: Data?   // In-memory cached avatar
    @Published var showResetPasswordSheet = false  // Deep link'ten tetiklenir
    @Published var isCheckingAuth = true           // Splash screen kontrolü

    @AppStorage("rememberMe") var rememberMe: Bool = true

    private let supabase = SupabaseManager.shared.client
    private var currentNonce: String?

    init() {
        Task { await checkSession(); listenAuthChanges() }
    }

    // MARK: - Session

    func checkSession() async {
        defer { isCheckingAuth = false }
        if !rememberMe { await signOut(); return }
        do {
            let session = try await supabase.auth.session
            currentUserId = session.user.id
            AppGroup.defaults.set(session.user.id.uuidString, forKey: "current_user_id")
            currentUserEmail = session.user.email
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
                    if let uid = session?.user.id {
                        AppGroup.defaults.set(uid.uuidString, forKey: "current_user_id")
                    }
                    currentUserEmail = session?.user.email
                    isLoggedIn    = true
                    await fetchProfile()
                case .signedOut:
                    currentUserId = nil
                    currentUserEmail = nil
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
            AppGroup.defaults.set(s.user.id.uuidString, forKey: "current_user_id")
            currentUserEmail = s.user.email
            isLoggedIn    = true
            await fetchProfile()
            Haptic.success()
        } catch {
            errorMessage = friendlyError(error)
            Haptic.error()
        }
        isLoading = false
    }

    func signUp(email: String, password: String, fullName: String, phoneNumber: String?,
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
                phoneNumber: phoneNumber,
                avatarURL: nil
            )

            // 1. First insert profile
            try await supabase.from("profiles")
                .insert(profileInsert)
                .execute()

            // 2. Seed categories
            await seedCategories(userId: userId, userType: userType.rawValue)

            // 3. Update state AFTER success
            currentUserId = userId
            currentUserEmail = auth.user.email
            
            // Explicitly fetch the profile we just created to ensure it's in memory
            await fetchProfile()
            
            isLoggedIn = true // This triggers the UI transition
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
        } catch { 
            errorMessage = error.localizedDescription 
        }
        // Always clear local state even if the network fails
        await MainActor.run {
            self.isLoggedIn    = false
            self.currentUserId = nil
            AppGroup.defaults.removeObject(forKey: "current_user_id")
            self.currentUserEmail = nil
            self.userProfile   = nil
            self.userAvatarData = nil
            NotificationCenter.default.post(name: Notification.Name("ZFlowDidLogout"), object: nil)
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple() async {
        isLoading = true; errorMessage = nil
        let nonce = randomNonceString()
        currentNonce = nonce

        let coordinator = AppleSignInCoordinator(nonce: nonce)
        do {
            let result = try await coordinator.triggerRequest()
            // Authenticate against Supabase using the Apple ID token
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: result.idToken,
                    nonce: result.nonce
                )
            )
            let userId = session.user.id

            // Build a full name from Apple's components (only given on first sign-in)
            if let components = result.fullName,
               let givenName = components.givenName {
                let family = components.familyName ?? ""
                let fullName = "\(givenName) \(family)".trimmingCharacters(in: .whitespaces)
                // Upsert profile so it's created for brand-new users
                let insert = ProfileInsert(
                    id: userId,
                    fullName: fullName,
                    userType: "personal",
                    businessName: nil,
                    phoneNumber: nil,
                    avatarURL: nil
                )
                _ = try? await supabase.from("profiles").upsert(insert).execute()
                await seedCategories(userId: userId, userType: "personal")
            }

            currentUserId = userId
            currentUserEmail = session.user.email
            AppGroup.defaults.set(userId.uuidString, forKey: "current_user_id")
            await fetchProfile()
            isLoggedIn = true
            Haptic.success()
        } catch {
            errorMessage = friendlyError(error)
            Haptic.error()
        }
        isLoading = false
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

    func updateProfile(fullName: String, phoneNumber: String?, businessName: String?) async -> Bool {
        guard let uid = currentUserId else { return false }
        do {
            var updates: [String: String] = ["full_name": fullName]
            if let pn = phoneNumber { updates["phone_number"] = pn }
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

    func updateProfileThemes(appTheme: String, familyHex: String, walletHex: String) async -> Bool {
        guard let uid = currentUserId else { return false }
        do {
            try await supabase.from("profiles")
                .update([
                    "theme_app": appTheme,
                    "theme_family_card": familyHex,
                    "theme_wallet_card": walletHex
                ])
                .eq("id", value: uid.uuidString)
                .execute()
            
            await fetchProfile()
            return true
        } catch {
            print("⚠️ [Theme] Supabase sync failed (local save already done): \(error)")
            print("   → Supabase: profiles tablosunda theme_app, theme_family_card, theme_wallet_card kolonlarını ve UPDATE RLS policy'sini kontrol et")
            return false
        }
    }

    func updateEmail(newEmail: String) async -> Bool {
        isLoading = true; errorMessage = nil
        do {
            let attrs = UserAttributes(email: newEmail)
            let updatedUser = try await supabase.auth.update(user: attrs)
            currentUserEmail = updatedUser.email
            isLoading = false
            Haptic.success()
            return true
        } catch {
            errorMessage = friendlyError(error)
            isLoading = false
            Haptic.error()
            return false
        }
    }

    func updatePassword(newPassword: String) async -> Bool {
        isLoading = true; errorMessage = nil
        do {
            let attrs = UserAttributes(password: newPassword)
            _ = try await supabase.auth.update(user: attrs)
            isLoading = false
            Haptic.success()
            return true
        } catch {
            errorMessage = friendlyError(error)
            isLoading = false
            Haptic.error()
            return false
        }
    }

    func sendPasswordResetEmail(email: String) async -> Bool {
        isLoading = true; errorMessage = nil
        do {
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "zflow://reset-password")
            )
            isLoading = false
            Haptic.success()
            return true
        } catch {
            errorMessage = friendlyError(error)
            isLoading = false
            Haptic.error()
            return false
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        isLoading = true; errorMessage = nil
        do {
            // En üstteki VC'yi bul (iOS 15+ deprecated keyWindow yerine windows kullan)
            guard let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                  let root   = window.rootViewController else {
                errorMessage = NSLocalizedString("auth.googleFailed", comment: "")
                isLoading = false; return
            }
            // Sheet/overlay açıksa onun üstüne sun
            var topVC: UIViewController = root
            while let presented = topVC.presentedViewController { topVC = presented }

            // GIDConfiguration ZFlowApp.init() içinde bir kez ayarlandı, burada tekrar gerek yok.
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = NSLocalizedString("auth.googleFailed", comment: "")
                isLoading = false; return
            }

            // Supabase'e idToken + accessToken gönder (nonce gereksiz — panel yapılandırması yeterli)
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
            )

            currentUserId    = session.user.id
            currentUserEmail = session.user.email
            AppGroup.defaults.set(session.user.id.uuidString, forKey: "current_user_id")

            await handleSocialProfile(
                userId:   session.user.id,
                email:    session.user.email,
                fullName: result.user.profile?.name
            )
            isLoggedIn = true
            Haptic.success()
        } catch {
            let nsErr = error as NSError
            // GIDSignInError.canceled (code -5) — kullanıcı iptal etti, sessizce çık
            guard nsErr.code != -5 else { isLoading = false; return }
            print("❌ [Google] SignIn hatası: \(error)")
            errorMessage = friendlyError(error)
            Haptic.error()
        }
        isLoading = false
    }

    private func handleSocialProfile(userId: UUID, email: String?, fullName: String?) async {
        do {
            let existing: [Profile] = (try? await supabase.from("profiles")
                .select().eq("id", value: userId.uuidString).execute().value) ?? []
            if existing.isEmpty {
                let insert = ProfileInsert(
                    id: userId, fullName: fullName ?? "", userType: "personal",
                    businessName: nil, phoneNumber: nil, avatarURL: nil
                )
                try await supabase.from("profiles").insert(insert).execute()
                await seedCategories(userId: userId, userType: "personal")
            }
            await fetchProfile()
        } catch {
            print("❌ [Auth] Social profile error: \(error)")
        }
    }

    // MARK: - Private

    private func seedCategories(userId: UUID, userType: String) async {
        let inserts = filteredDefaultCategories(for: userType).map {
            CategoryInsert(userId: userId, familyId: nil, name: $0.name, color: $0.color, icon: $0.icon, type: $0.type)
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
