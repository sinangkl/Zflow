// ============================================================
// ZFlow — Push Notification Manager (APNs)
// ============================================================

import Foundation
import Combine
import UIKit
import UserNotifications

@MainActor
final class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()

    @Published var apnsToken: String?
    @Published var isRegistered = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Registration

    func requestPermissionAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.apnsToken = token
        self.isRegistered = true
        Task { await uploadTokenToBackend(token) }
    }

    func didFailToRegister(error: Error) {
        print("❌ [APNs] Failed to register: \(error)")
    }

    // MARK: - Backend Token Upload

    private func uploadTokenToBackend(_ token: String) async {
        guard let url = URL(string: "\(AppConstants.serverURL)/api/push/register") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])
        _ = try? await URLSession.shared.data(for: req)
        print("✅ [APNs] Token registered with backend")
    }

    // MARK: - Foreground Notification Handling

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap — deep link to relevant screen
        let userInfo = response.notification.request.content.userInfo
        if let screen = userInfo["screen"] as? String {
            NotificationCenter.default.post(
                name: Notification.Name("ZFlowDeepLink"),
                object: nil,
                userInfo: ["screen": screen]
            )
        }
        completionHandler()
    }
}
