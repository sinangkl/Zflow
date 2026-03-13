// ============================================================
// ZFlow — AppConstants
// 
// Central configuration for API endpoints and other global settings.
// ============================================================

import Foundation

public struct AppConstants {
    /// The base URL for the ZFlow Python backend server.
    /// Used for push registration, receipt scanning, and family invites.
    #if DEBUG
    // Use localhost for local development (adjust port if needed)
    public static let serverURL = "https://zflow.online"
    #else
    // Production URL
    public static let serverURL = "https://zflow.online"
    #endif

    /// The App Group identifier for sharing data between App, Widgets, and Watch.
    public static let appGroupId = "group.com.zflow.app"
}
