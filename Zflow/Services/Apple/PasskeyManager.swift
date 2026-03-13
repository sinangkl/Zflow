// ============================================================
// ZFlow — Passkey Manager (WebAuthn / ASAuthorization)
// iOS 16+ Passkey Registration & Authentication
// ============================================================

import Foundation
import Combine
import SwiftUI
import AuthenticationServices

@MainActor
final class PasskeyManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    @Published var isRegistered = false
    @Published var errorMessage: String?

    private var registrationContinuation: CheckedContinuation<Bool, Error>?

    // MARK: - Register

    func registerPasskey(for username: String) async -> Bool {
        guard #available(iOS 16.0, *) else {
            errorMessage = "Passkey iOS 16 gerektirir."
            return false
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "zflow.app")
        let challenge = generateChallenge()
        
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: username,
            userID: Data(username.utf8)
        )

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        do {
            let success = try await withCheckedThrowingContinuation { [weak self] cont in
                self?.registrationContinuation = cont
                controller.performRequests()
            }
            isRegistered = success
            return success
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Authenticate

    func authenticateWithPasskey() async -> Bool {
        guard #available(iOS 16.0, *) else { return false }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "zflow.app")
        let challenge = generateChallenge()
        let request = provider.createCredentialAssertionRequest(challenge: challenge)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        do {
            let result = try await withCheckedThrowingContinuation { [weak self] cont in
                self?.registrationContinuation = cont
                controller.performRequests()
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Delegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if authorization.credential is ASAuthorizationPlatformPublicKeyCredentialRegistration {
            print("✅ [Passkey] Registered successfully")
            registrationContinuation?.resume(returning: true)
        } else if authorization.credential is ASAuthorizationPlatformPublicKeyCredentialAssertion {
            print("✅ [Passkey] Authenticated successfully")
            registrationContinuation?.resume(returning: true)
        } else {
            registrationContinuation?.resume(returning: false)
        }
        registrationContinuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ [Passkey] Error: \(error)")
        // Cancelled by user is not an error to surface
        if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
            errorMessage = error.localizedDescription
        }
        registrationContinuation?.resume(returning: false)
        registrationContinuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first ?? UIWindow()
    }

    // MARK: - Helpers

    private func generateChallenge() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
