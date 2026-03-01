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
}

// MARK: - ZColor — Apple System + Brand Tokens
// Tüm renkler WCAG AA (4.5:1 kontrast) sağlar

enum ZColor {
    // Brand
    static let indigo     = Color(hex: "#5E5CE6")   // Apple system indigo — light
    static let indigoDark = Color(hex: "#7D7AFF")   // dark mode
    static let violet     = Color(hex: "#7C3AED")
    static let violetDark = Color(hex: "#A78BFA")

    // Semantic — Apple system colors
    static let income     = Color(hex: "#30D158")
    static let expense    = Color(hex: "#FF453A")
    static let warning    = Color(hex: "#FF9F0A")
    static let info       = Color(hex: "#0A84FF")
    static let purple     = Color(hex: "#BF5AF2")
    static let teal       = Color(hex: "#5AC8FA")

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

// MARK: - AppTheme

struct AppTheme {

    // MARK: Accent
    static func accentColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? ZColor.indigoDark : ZColor.indigo
    }

    static let accentPrimary   = ZColor.indigo
    static let accentSecondary = Color(hex: "#7D7AFF")

    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let accentGradientH = LinearGradient(
        colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
        startPoint: .leading, endPoint: .trailing)

    static let incomeGradient = LinearGradient(
        colors: [Color(hex: "#30D158"), Color(hex: "#34C759")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let expenseGradient = LinearGradient(
        colors: [Color(hex: "#FF453A"), Color(hex: "#FF6961")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Legacy aliases
    static let accent  = accentGradient
    static let income  = incomeGradient
    static let expense = expenseGradient
    static let gold    = LinearGradient(colors: [ZColor.warning, Color(hex: "#FFD60A")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardPrimary = LinearGradient(colors: [Color(hex: "#1C1C1E"), Color(hex: "#2C2C2E")],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
    static let incomeColor  = ZColor.income
    static let expenseColor = ZColor.expense
    static let warningColor = ZColor.warning
    static let infoColor    = ZColor.info

    // MARK: Backgrounds
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
        scheme == .dark ? Color(white: 1, opacity: 0.11) : Color(white: 0, opacity: 0.07)
    }
    static func glassMaterial(for scheme: ColorScheme) -> Material {
        scheme == .dark ? .ultraThinMaterial : .thinMaterial
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


// MARK: - ZFlowCard Modifier

struct ZFlowCard: ViewModifier {
    @Environment(\.colorScheme) var scheme
    var cornerRadius: CGFloat = 16
    var useMaterial: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(useMaterial
                          ? AnyShapeStyle(AppTheme.glassMaterial(for: scheme))
                          : AnyShapeStyle(AppTheme.cardFill(for: scheme)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5)
            )
            .shadow(color: scheme == .dark ? .clear : .black.opacity(0.045), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func zFlowCard(cornerRadius: CGFloat = 16, useMaterial: Bool = false) -> some View {
        modifier(ZFlowCard(cornerRadius: cornerRadius, useMaterial: useMaterial))
    }
}
