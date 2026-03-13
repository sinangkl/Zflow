import SwiftUI

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        switch h.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: 1)
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#5E5CE6" }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

// MARK: - ZColor — Apple System + Brand Tokens (2026 Liquid Glass)

enum ZColor {
    // Brand
    static let indigo     = Color(hex: "#5E5CE6")
    static let indigoDark = Color(hex: "#7D7AFF")
    static let violet     = Color(hex: "#7C3AED")
    static let violetDark = Color(hex: "#A78BFA")

    // Semantic — Soft pastel tones
    static let income     = Color(hex: "#50C878")   // Soft Emerald
    static let expense    = Color(hex: "#FF7F7F")   // Soft Coral
    static let warning    = Color(hex: "#FF9F0A")
    static let info       = Color(hex: "#0A84FF")
    static let purple     = Color(hex: "#BF5AF2")
    static let teal       = Color(hex: "#5AC8FA")

    // Liquid Glass accent colors
    static let neonBlue   = Color(hex: "#00D4FF")
    static let neonPurple = Color(hex: "#A855F7")
    static let neonPink   = Color(hex: "#EC4899")
    static let mint       = Color(hex: "#34D399")
    static let amber      = Color(hex: "#FBBF24")
    
    // Premium Assist (Burgundy & Gold)
    static let burgundy   = Color(hex: "#4A0404")
    static let gold       = Color(hex: "#D4AF37")

    // Adaptive system surfaces
    static let bg         = Color(.systemBackground)
    static let bgSec      = Color(.secondarySystemBackground)
    static let bgTert     = Color(.tertiarySystemBackground)
    static let grouped    = Color(.systemGroupedBackground)
    static let groupedSec = Color(.secondarySystemGroupedBackground)
    static let groupedTert = Color(.tertiarySystemGroupedBackground)

    // Labels
    static let label      = Color(.label)
    static let labelSec   = Color(.secondaryLabel)
    static let labelTert  = Color(.tertiaryLabel)
    static let labelQuart = Color(.quaternaryLabel)

    // Fills
    static let fill       = Color(.systemFill)
    static let fillSec    = Color(.secondarySystemFill)
    static let fillTert   = Color(.tertiarySystemFill)
    static let fillQuart  = Color(.quaternarySystemFill)

    // Separators
    static let separator  = Color(.separator)
    static let sepOpaque  = Color(.opaqueSeparator)
}

// MARK: - AppTheme (Liquid Glass 2026)

struct AppTheme {

    // MARK: Card Radius
    static let cardRadius: CGFloat = 24
    static let heroRadius: CGFloat = 28
    static let smallRadius: CGFloat = 16

    // MARK: Dynamic Theme Color
    static var baseColorHex: String {
        UserDefaults.standard.string(forKey: "profileCardColor") ?? "#5E5CE6"
    }
    
    static var baseColor: Color {
        Color(hex: baseColorHex)
    }

    static var accentSecondary: Color {
        switch baseColorHex.uppercased() {
        case "#5E5CE6": return Color(hex: "#7C3AED") // Indigo -> Deep Violet
        case "#0A84FF": return Color(hex: "#5AC8FA") // Blue -> Cyan
        case "#30D158": return Color(hex: "#34C759") // Green -> Mint
        case "#FF9F0A": return Color(hex: "#FFD60A") // Orange -> Yellow
        case "#FF375F": return Color(hex: "#FF6482") // Pink -> Lighter Pink
        case "#BF5AF2": return Color(hex: "#D484FA") // Purple -> Lighter Purple
        case "#00C7BE": return Color(hex: "#5AC8FA") // Teal -> Sky
        case "#FF6B6B": return Color(hex: "#FF3B30") // Coral -> Red
        case "#FFD60A": return Color(hex: "#FF9F0A") // Gold -> Orange
        case "#34D399": return Color(hex: "#30D158") // Mint -> Green
        case "#FF3B30": return Color(hex: "#FF6B6B") // Red -> Coral
        case "#5AC8FA": return Color(hex: "#00C7BE") // Sky -> Teal
        default: return baseColor.opacity(0.8)
        }
    }

    // MARK: Accent
    static func accentColor(for scheme: ColorScheme) -> Color {
        baseColor
    }

    static var accentPrimary: Color { baseColor }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [baseColor, accentSecondary],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var accentGradientH: LinearGradient {
        LinearGradient(
            colors: [baseColor, accentSecondary],
            startPoint: .leading, endPoint: .trailing)
    }

    static let incomeGradient = LinearGradient(
        colors: [Color(hex: "#50C878"), Color(hex: "#3DA86B")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let expenseGradient = LinearGradient(
        colors: [Color(hex: "#FF7F7F"), Color(hex: "#E86060")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Liquid Glass specific gradients
    static var liquidGlassGradient: LinearGradient {
        LinearGradient(
            colors: [
                baseColor.opacity(0.6),
                Color(hex: "#7C3AED").opacity(0.4),
                baseColor.opacity(0.3)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let frostGlassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.15),
            Color.white.opacity(0.05),
            Color.white.opacity(0.10)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static var neonAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#00D4FF"),
                baseColor,
                Color(hex: "#A855F7")
            ],
            startPoint: .leading, endPoint: .trailing)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#4338CA"),
                baseColor,
                Color(hex: "#7C3AED")
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Legacy aliases
    static var accent: LinearGradient { accentGradient }
    static let income  = incomeGradient
    static let expense = expenseGradient
    static var gold    = LinearGradient(colors: [ZColor.gold, Color(hex: "#FFD60A")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let burgundy = LinearGradient(colors: [ZColor.burgundy, Color(hex: "#2D0202")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
    static var cardPrimary: LinearGradient {
        LinearGradient(colors: [Color(hex: "#1C1C1E"), Color(hex: "#2C2C2E")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static let incomeColor  = ZColor.income
    static let expenseColor = ZColor.expense
    static let warningColor = ZColor.warning
    static let infoColor    = ZColor.info

    // MARK: Backgrounds — Liquid Glass
    static func cardFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 1, opacity: 0.08) : Color(.secondarySystemGroupedBackground)
    }
    static func listRowFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 1, opacity: 0.05) : Color(.secondarySystemGroupedBackground)
    }
    static func fieldFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 1, opacity: 0.11) : Color(.tertiarySystemFill)
    }
    static func cardBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 1, opacity: 0.13) : Color(white: 0, opacity: 0.07)
    }
    static func glassBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 1, opacity: 0.18) : Color(white: 0, opacity: 0.08)
    }
    static func glassMaterial(for scheme: ColorScheme) -> Material {
        return .ultraThinMaterial
    }
    static func glassOverlay(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 1, opacity: 0.04) : Color(white: 1, opacity: 0.6)
    }
}

// MARK: - Number Formatting

extension Double {
    func formattedCurrency(code: String = "TRY") -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = ["JPY","KRW"].contains(code) ? 0 : 2
        f.minimumFractionDigits = ["JPY","KRW"].contains(code) ? 0 : 2
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - ZFlowCard Modifier (Liquid Glass)

struct ZFlowCard: ViewModifier {
    @Environment(\.colorScheme) var scheme
    var cornerRadius: CGFloat = 24
    var useMaterial: Bool = false
    var borderOpacity: CGFloat = 1.0

    func body(content: Content) -> some View {
        let isDark = scheme == .dark
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(useMaterial
                          ? AnyShapeStyle(AppTheme.glassMaterial(for: scheme))
                          : AnyShapeStyle(AppTheme.cardFill(for: scheme)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                isDark ? Color.white.opacity(0.3 * borderOpacity) : Color.black.opacity(0.08 * borderOpacity),
                                isDark ? Color.white.opacity(0.05 * borderOpacity) : Color.black.opacity(0.02 * borderOpacity),
                                .clear,
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: scheme == .dark
                    ? AppTheme.baseColor.opacity(0.06)
                    : .black.opacity(0.05),
                    radius: 12, x: 0, y: 4)
            // Inner Glow / Glass Thickness Simulation
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                isDark ? Color.white.opacity(0.25 * borderOpacity) : Color.black.opacity(0.04 * borderOpacity),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .blur(radius: 2)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
    }
}

extension View {
    func zFlowCard(cornerRadius: CGFloat = 24, useMaterial: Bool = false, borderOpacity: CGFloat = 1.0) -> some View {
        modifier(ZFlowCard(cornerRadius: cornerRadius, useMaterial: useMaterial, borderOpacity: borderOpacity))
    }
}



// MARK: - Animated Gradient Border

struct AnimatedGradientBorder: View {
    var cornerRadius: CGFloat = 20
    var lineWidth: CGFloat = 1.5
    @Environment(\.colorScheme) var scheme

    var colors: [Color] {
        scheme == .dark ? [
            Color(hex: "#5E5CE6"),
            Color(hex: "#00D4FF"),
            Color(hex: "#A855F7"),
            Color(hex: "#EC4899"),
            Color(hex: "#5E5CE6")
        ] : [
            Color(hex: "#4338CA"),
            Color(hex: "#0084FF"),
            Color(hex: "#7C3AED"),
            Color(hex: "#D4356B"),
            Color(hex: "#4338CA")
        ]
    }
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    colors: colors,
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: lineWidth
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var scheme

    func makeBody(configuration: Configuration) -> some View {
        let isDark = scheme == .dark
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.glassOverlay(for: scheme))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.08),
                                isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PrimaryGlassButtonStyle: ButtonStyle {
    var gradient: LinearGradient = AppTheme.accentGradient
    @Environment(\.colorScheme) var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: AppTheme.baseColor.opacity(scheme == .dark ? 0.3 : 0.2), radius: 12, x: 0, y: 6)
            .shadow(color: AppTheme.baseColor.opacity(scheme == .dark ? 0.1 : 0.08), radius: 2, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Glow Effect Modifier

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.25), radius: radius * 2, x: 0, y: 0)
    }
}

// MARK: - Ambient Glow (Ligthing Phase 1)

struct AmbientGlowModifier: ViewModifier {
    @Environment(\.colorScheme) var scheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RadialGradient(
                    colors: [
                        scheme == .dark ? AppTheme.baseColor.opacity(0.2) : AppTheme.baseColor.opacity(0.15),
                        .clear
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 250
                )
            )
    }
}

extension View {
    func ambientGlow() -> some View {
        modifier(AmbientGlowModifier())
    }

    func glow(color: Color = AppTheme.baseColor, radius: CGFloat = 8) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Card Entry Animation

struct CardEntryModifier: ViewModifier {
    var delay: Double = 0
    @State private var appeared = false

     func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func cardEntry(delay: Double = 0) -> some View {
        modifier(CardEntryModifier(delay: delay))
    }
}

// MARK: - Subtle Pulse Animation

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.03 : 1.0)
            .opacity(isPulsing ? 0.85 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulse() -> some View {
        modifier(PulseModifier())
    }
}

// MARK: - AI Badge

struct AIBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("AI")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#5E5CE6"), Color(hex: "#A855F7")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
        )
        .shadow(color: AppTheme.baseColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
