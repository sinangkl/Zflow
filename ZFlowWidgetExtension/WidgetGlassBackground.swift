import SwiftUI

// MARK: - Widget Gradient Background
// Used inside .containerBackground(for: .widget) { … }
// Default (indigo) theme uses vivid brand violet/navy; other themes use muted overlays.

struct WidgetGradientBackground: View {
    let snapshot: ZFlowSnapshot
    @Environment(\.colorScheme) var scheme

    // True when the user hasn't changed the theme (indigo = brand/logo default)
    private var isDefaultTheme: Bool {
        (snapshot.accentPrimaryHex?.uppercased() ?? "") == "#5E5CE6"
    }

    var body: some View {
        let isDark = scheme == .dark

        ZStack {
            if isDark {
                if isDefaultTheme {
                    // Default logo gradient — vivid violet/navy brand identity
                    LinearGradient(
                        colors: [
                            Color(hex: "#4D1590"), // Vivid violet
                            Color(hex: "#2E0E6B"), // Deep violet
                            Color(hex: "#080820")  // Near-black navy
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    // Ambient indigo glow
                    GeometryReader { geo in
                        Circle()
                            .fill(Color(hex: "#5E5CE6").opacity(0.28))
                            .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                            .blur(radius: geo.size.width * 0.30)
                            .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.15)
                    }
                    .clipped()
                } else {
                    // Other themes — universal dark base + muted theme tint
                    // Reduced opacity (0.35/0.18) ensures text is always readable
                    let primaryHex = snapshot.accentPrimaryHex ?? "#5E5CE6"
                    let secondaryHex = snapshot.accentSecondaryHex ?? "#2E0E6B"
                    Color(hex: "#07071A") // Universal near-black base
                    LinearGradient(
                        colors: [
                            Color(hex: primaryHex).opacity(0.35),
                            Color(hex: secondaryHex).opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    // Ambient glow — dimmer for non-default themes
                    GeometryReader { geo in
                        Circle()
                            .fill(Color(hex: primaryHex).opacity(0.18))
                            .frame(width: geo.size.width * 0.85, height: geo.size.width * 0.85)
                            .blur(radius: geo.size.width * 0.35)
                            .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.20)
                    }
                    .clipped()
                }
            } else {
                if isDefaultTheme {
                    // Default light — soft lavender/mint/sky brand palette
                    LinearGradient(
                        colors: [
                            Color(hex: "#E8D5F5"), // Lavender
                            Color(hex: "#D0F0F7"), // Sky
                            Color(hex: "#FAF9FF")  // Near-white
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    // Other themes light — very subtle tint (already readable)
                    let primaryHex = snapshot.accentPrimaryHex ?? "#5E5CE6"
                    let secondaryHex = snapshot.accentSecondaryHex ?? "#2E0E6B"
                    LinearGradient(
                        colors: [
                            Color(hex: primaryHex).opacity(0.10),
                            Color(hex: secondaryHex).opacity(0.15),
                            Color(hex: "#D4EEF8")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }
}

// MARK: - Widget Glass Overlay
// Layered inside widget ZStack on top of WidgetGradientBackground.
// Keeps the premium frosted look without hiding the gradient.

struct WidgetGlassBackground: View {
    @Environment(\.colorScheme) var scheme

    var body: some View {
        let isDark = scheme == .dark
        LinearGradient(
            colors: [
                Color.white.opacity(isDark ? 0.05 : 0.22),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func widgetGlass() -> some View {
        self.background(WidgetGlassBackground())
    }
}
