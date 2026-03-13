import SwiftUI

public enum ThemeColors {
    public static let deepNeonAzure = Color(red: 0.0, green: 0.5, blue: 1.0)
    public static let vibrantViolet = Color(red: 0.5, green: 0.0, blue: 1.0)

    public static let glassBackground = Color.white.opacity(0.1)
    public static let glassBorder = Color.white.opacity(0.2)


    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary

    // Mesh Gradient Core Colors — Dark Mode (vivid, NO black areas)
    public static let meshDarkOcean = Color(hex: "#0E1145")          // deep indigo (NOT black)
    public static let meshDarkNeonPurple = Color(hex: "#2E0E6B")     // vivid deep violet
    public static let meshDarkDeepAzure = Color(hex: "#0C1D5E")      // rich navy blue
    public static let meshDarkVibrantViolet = Color(hex: "#4D1590")  // bright purple accent

    // Mesh Gradient Core Colors — Light Mode (Lavender / Mint / Sky palette — vibrant but soft)
    public static let meshLightPastelLilac = Color(hex: "#E0C7F5")  // lavender (more vibrant)
    public static let meshLightIceBlue = Color(hex: "#C5E8F5")      // sky blue (more saturated)
    public static let meshLightSoftBlue = Color(hex: "#D4F1DB")     // mint green (fresher)
    public static let meshLightWarmWhite = Color(hex: "#FDFBFF")    // near-white base (warmer)

    // Dynamic background for Light and Dark modes
    public static let background = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
            : UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1.0)
    })

    // Keep legacy name for compatibility but route to dynamic
    public static var darkBackground: Color { background }
}
