import SwiftUI

public struct MeshGradientBackground: View {
    @State private var animate = false
    @Environment(\.colorScheme) var scheme

    public init() {}

    public var body: some View {
        let isDark = scheme == .dark
        
        let colors: [Color] = isDark ? [
            ThemeColors.meshDarkOcean, ThemeColors.meshDarkNeonPurple.opacity(0.8), ThemeColors.meshDarkOcean,
            ThemeColors.meshDarkDeepAzure.opacity(0.6), ThemeColors.meshDarkOcean, ThemeColors.meshDarkDeepAzure.opacity(0.7),
            ThemeColors.meshDarkOcean, ThemeColors.meshDarkVibrantViolet.opacity(0.5), ThemeColors.meshDarkOcean
        ] : [
            ThemeColors.meshLightWarmWhite, ThemeColors.meshLightPastelLilac.opacity(0.8), ThemeColors.meshLightWarmWhite,
            ThemeColors.meshLightIceBlue.opacity(0.6), ThemeColors.meshLightWarmWhite, ThemeColors.meshLightIceBlue.opacity(0.7),
            ThemeColors.meshLightWarmWhite, ThemeColors.meshLightSoftBlue.opacity(0.5), ThemeColors.meshLightWarmWhite
        ]
        
        Group {
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        .init(0, 0), .init(0.5, 0), .init(1, 0),
                        .init(0, 0.5), .init(animate ? 0.8 : 0.2, animate ? 0.8 : 0.2), .init(1, 0.5),
                        .init(0, 1), .init(0.5, 1), .init(1, 1)
                    ],
                    colors: colors
                )
                .ignoresSafeArea()
            } else {
                // Fallback for older iOS versions
                LinearGradient(
                    colors: isDark ? [
                        ThemeColors.meshDarkOcean,
                        ThemeColors.meshDarkNeonPurple.opacity(0.6),
                        ThemeColors.meshDarkDeepAzure.opacity(0.5),
                        ThemeColors.meshDarkOcean
                    ] : [
                        ThemeColors.meshLightWarmWhite,
                        ThemeColors.meshLightPastelLilac.opacity(0.6),
                        ThemeColors.meshLightIceBlue.opacity(0.5),
                        ThemeColors.meshLightWarmWhite
                    ],
                    startPoint: animate ? .topLeading : .bottomTrailing,
                    endPoint: animate ? .bottomTrailing : .topLeading
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
