import SwiftUI

public struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var borderOpacity: Double
    @Environment(\.colorScheme) var scheme

    public func body(content: Content) -> some View {
        let isDarkContent = scheme == .dark

        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                isDarkContent ? Color.white.opacity(0.2) : Color.black.opacity(0.08),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            // Single Shadow — optimized
            .shadow(color: Color.black.opacity(isDarkContent ? 0.15 : 0.06), radius: 10, x: 0, y: 4)
    }
}

public extension View {
    func liquidGlass(cornerRadius: CGFloat = 24, borderOpacity: Double = 0.5, isDark: Bool? = nil) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
}
