import SwiftUI

// MARK: - Splash Screen
// Oturum kontrolü yapılırken gösterilen animasyonlu ekran.
// Light & dark mode fully adaptive.

struct SplashView: View {
    @Environment(\.colorScheme) var scheme
    @AppStorage("profileCardColor") private var themeHex: String = "#5E5CE6"

    @State private var logoScale:   CGFloat = 0.72
    @State private var logoOpacity: Double  = 0
    @State private var glowScale:   CGFloat = 0.5
    @State private var textOffset:  CGFloat = 14
    @State private var textOpacity: Double  = 0
    @State private var ringPulse                = false

    private var accent:          Color { Color(hex: themeHex) }
    private var accentSecondary: Color { AppTheme.accentSecondary }

    var body: some View {
        ZStack {
            // ── Background
            MeshGradientBackground().ignoresSafeArea()

            // ── Soft centre atmospheric glow
            RadialGradient(
                colors: [accent.opacity(scheme == .dark ? 0.22 : 0.12), .clear],
                center: .center, startRadius: 0, endRadius: 300)
            .ignoresSafeArea()

            VStack(spacing: 26) {

                // ── Logo ───────────────────────────────────────────────
                ZStack {
                    // Ambient halo (pulsing)
                    Circle()
                        .fill(RadialGradient(
                            colors: [accent.opacity(scheme == .dark ? 0.55 : 0.28), .clear],
                            center: .center, startRadius: 0, endRadius: 90))
                        .frame(width: 180)
                        .blur(radius: 28)
                        .scaleEffect(glowScale)

                    // Pulse ring
                    Circle()
                        .stroke(accent.opacity(scheme == .dark ? 0.18 : 0.12), lineWidth: 0.8)
                        .frame(width: 112)
                        .scaleEffect(ringPulse ? 1.12 : 0.94)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: ringPulse)

                    // Glass disk
                    Circle()
                        .fill(scheme == .dark
                              ? AnyShapeStyle(.ultraThinMaterial)
                              : AnyShapeStyle(Color.white.opacity(0.94)))
                        .frame(width: 92, height: 92)
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: scheme == .dark
                                        ? [Color.white.opacity(0.50), accent.opacity(0.18)]
                                        : [Color.white, accent.opacity(0.40)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: scheme == .dark ? 0.8 : 1.0)
                        )
                        .shadow(color: accent.opacity(scheme == .dark ? 0.60 : 0.30), radius: 32, y: 12)
                        .shadow(color: accent.opacity(scheme == .dark ? 0.20 : 0.10), radius: 6, y: 3)

                    // Icon
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [accent, accentSecondary],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // ── Text ───────────────────────────────────────────────
                VStack(spacing: 9) {
                    Text("ZFlow")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            scheme == .dark
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.white, Color(hex: "#E8E4FF"), accent.opacity(0.80)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(LinearGradient(
                                colors: [accent, accentSecondary],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .tracking(-1.2)
                        .shadow(color: accent.opacity(scheme == .dark ? 0.40 : 0.18), radius: 10, y: 4)

                    Text(NSLocalizedString("onboarding.tagline", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(
                            scheme == .dark
                                ? Color.white.opacity(0.44)
                                : Color(.secondaryLabel)
                        )
                        .tracking(0.2)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.72, dampingFraction: 0.68).delay(0.10)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.30)) {
            textOffset  = 0
            textOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.50)) {
            glowScale = 1.30
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            ringPulse = true
        }
    }
}

#Preview {
    SplashView()
}
