// ============================================================
// ZFlow — UIApplicationDelegate
// Handles APNs token registration callbacks
// and other UIKit-level app lifecycle events.
// ============================================================

import UIKit

final class ZFlowAppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - APNs Token Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.didFailToRegister(error: error)
    }

    // MARK: - Universal Links / Deep Links (pass-through to SwiftUI onOpenURL)

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // Associated Domains / Universal Links handled here if needed
        return false
    }
}
