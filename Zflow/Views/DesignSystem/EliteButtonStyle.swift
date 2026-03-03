import SwiftUI

public struct EliteButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ThemeColors.textPrimary)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .background(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                ThemeColors.deepNeonAzure.opacity(0.8),
                                ThemeColors.vibrantViolet.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: ThemeColors.deepNeonAzure.opacity(configuration.isPressed ? 0.6 : 0.2),
                radius: configuration.isPressed ? 15 : 8,
                x: 0,
                y: configuration.isPressed ? 8 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.8), trigger: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == EliteButtonStyle {
    static var elite: EliteButtonStyle { .init() }
}
