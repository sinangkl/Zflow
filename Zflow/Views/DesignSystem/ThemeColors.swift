import SwiftUI

public enum ThemeColors {
    public static let deepNeonAzure = Color(red: 0.0, green: 0.5, blue: 1.0)
    public static let vibrantViolet = Color(red: 0.5, green: 0.0, blue: 1.0)

    public static let glassBackground = Color.white.opacity(0.1)
    public static let glassBorder = Color.white.opacity(0.2)


    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary

    // Mesh Gradient Core Colors — Dark Mode
    public static let meshDarkOcean = Color(hex: "#050B14")
    public static let meshDarkNeonPurple = Color(hex: "#2B0B3B")
    public static let meshDarkDeepAzure = Color(hex: "#0B1536")
    public static let meshDarkVibrantViolet = Color(hex: "#340A59")

    // Mesh Gradient Core Colors — Light Mode (Lavender / Mint / Sky Blue)
    public static let meshLightPastelLilac = Color(hex: "#E8D5F5")   // Soft lavender
    public static let meshLightIceBlue = Color(hex: "#D0F0F7")       // Sky blue
    public static let meshLightSoftBlue = Color(hex: "#C8E6C9")      // Mint green
    public static let meshLightWarmWhite = Color(hex: "#F8F7FC")     // Off-white lavender tint

    // Dynamic background for Light and Dark modes
    public static let background = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
            : UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1.0)
    })

    // Keep legacy name for compatibility but route to dynamic
    public static var darkBackground: Color { background }
}
