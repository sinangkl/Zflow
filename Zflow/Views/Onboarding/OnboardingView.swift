import SwiftUI

// MARK: - Onboarding Coordinator

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var stage = 0   // 0 = splash  1 = carousel

    var body: some View {
        ZStack {
            LiquidNightBackground()

            if stage == 0 {
                ZFlowSplash()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.08).combined(with: .opacity)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                                stage = 1
                            }
                        }
                    }
            } else {
                OnboardingCarousel(onComplete: onComplete)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity))
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.6, dampingFraction: 0.82), value: stage)
    }
}

// MARK: - Liquid Night Background
// 5 katman renk + conic halo — iOS 26 Liquid Glass zemini

struct LiquidNightBackground: View {
    @State private var a = false

    var body: some View {
        ZStack {
            // Deep space base
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#000000"), location: 0),
                    .init(color: Color(hex: "#050510"), location: 0.45),
                    .init(color: Color(hex: "#020208"), location: 1),
                ],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            // --- Aurora orbs ---

            // Indigo — top-left (primary)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#5E5CE6").opacity(0.70), .clear],
                        center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 400)
                .blur(radius: 60)
                .offset(x: a ? -70 : -120, y: a ? -200 : -260)
                .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: a)

            // Violet — top-right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#7C3AED").opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: 170))
                .frame(width: 340)
                .blur(radius: 55)
                .offset(x: a ? 130 : 80, y: a ? -140 : -190)
                .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: a)

            // Cyan — mid accent
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#0EA5E9").opacity(0.28), .clear],
                        center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300)
                .blur(radius: 70)
                .offset(x: a ? 30 : -15, y: a ? 40 : 100)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: a)

            // Emerald — bottom-left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#059669").opacity(0.22), .clear],
                        center: .center, startRadius: 0, endRadius: 170))
                .frame(width: 340)
                .blur(radius: 90)
                .offset(x: a ? -90 : -45, y: a ? 390 : 330)
                .animation(.easeInOut(duration: 14).repeatForever(autoreverses: true), value: a)

            // Rose — bottom-right (contrast accent)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#EC4899").opacity(0.14), .clear],
                        center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260)
                .blur(radius: 80)
                .offset(x: a ? 110 : 75, y: a ? 500 : 420)
                .animation(.easeInOut(duration: 11).repeatForever(autoreverses: true), value: a)

            // Fine noise overlay — depth
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.04))
                .ignoresSafeArea()
        }
        .onAppear { a = true }
    }
}

// MARK: - Splash Screen
// World-class reveal: logo assembles from particles, rings bloom

struct ZFlowSplash: View {
    @State private var logoScale: CGFloat   = 0.18
    @State private var logoOp: Double       = 0
    @State private var ringOp: Double       = 0
    @State private var ringScale: CGFloat   = 0.6
    @State private var textOp: Double       = 0
    @State private var subOp: Double        = 0
    @State private var subY: CGFloat        = 24
    @State private var pulse                = false
    @State private var orbiting            = false
    @State private var haloRotation: Double = 0
    @State private var particleOp: Double   = 0

    // Floating feature pills
    @State private var pill1Y: CGFloat = 60
    @State private var pill2Y: CGFloat = -60
    @State private var pill3Y: CGFloat = 80
    @State private var pillOp: Double  = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Feature pills floating in background
                featurePills(geo: geo)

                VStack(spacing: 0) {
                    Spacer()

                    // Logo assembly
                    ZStack {
                        // Outer glow halo
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(hex: "#5E5CE6").opacity(0.35), .clear],
                                    center: .center, startRadius: 0, endRadius: 140))
                            .frame(width: 280)
                            .blur(radius: 30)
                            .scaleEffect(pulse ? 1.15 : 0.9)
                            .opacity(ringOp * 0.7)
                            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: pulse)

                        // Rotating conic gradient ring (outer)
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        Color(hex: "#5E5CE6").opacity(0.9),
                                        Color(hex: "#7D7AFF").opacity(0.6),
                                        .clear,
                                        Color(hex: "#5E5CE6").opacity(0.9),
                                    ],
                                    center: .center),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .frame(width: 148)
                            .rotationEffect(.degrees(haloRotation))
                            .opacity(ringOp)

                        // Inner dashed ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                            .frame(width: 118)
                            .rotationEffect(.degrees(-haloRotation * 0.5))
                            .opacity(ringOp * 0.6)

                        // Pulse rings (3 layers)
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(
                                    Color(hex: "#5E5CE6").opacity(0.30 - Double(i) * 0.08),
                                    lineWidth: 0.6)
                                .frame(width: CGFloat(128 + i * 38))
                                .scaleEffect(pulse ? 1.06 : 0.95)
                                .opacity(ringOp * (0.6 - Double(i) * 0.15))
                                .animation(
                                    .easeInOut(duration: 2.2 + Double(i) * 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.3),
                                    value: pulse)
                        }

                        // Orbiting dot
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#7D7AFF"))
                                .frame(width: 7, height: 7)
                                .shadow(color: Color(hex: "#5E5CE6"), radius: 6)
                        }
                        .offset(y: -72)
                        .rotationEffect(.degrees(orbiting ? 360 : 0))
                        .opacity(ringOp)
                        .animation(
                            .linear(duration: 4).repeatForever(autoreverses: false),
                            value: orbiting)

                        // Glass logo circle
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.45),
                                                    Color.white.opacity(0.05),
                                                    Color(hex: "#5E5CE6").opacity(0.20),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing),
                                            lineWidth: 0.8)
                                )
                                .shadow(color: Color(hex: "#5E5CE6").opacity(0.8), radius: 40, y: 16)

                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, Color(hex: "#C4B5FD")],
                                        startPoint: .top, endPoint: .bottom))
                        }
                        .scaleEffect(logoScale)
                        .opacity(logoOp)
                    }

                    Spacer().frame(height: 38)

                    // Wordmark
                    VStack(spacing: 10) {
                        Text("ZFlow")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color(hex: "#C4B5FD"),
                                        Color(hex: "#818CF8"),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                            .tracking(-1.2)
                            .opacity(textOp)

                        Text(NSLocalizedString("onboarding.tagline", comment: ""))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.48))
                            .tracking(0.2)
                            .opacity(subOp)
                            .offset(y: subY)
                    }

                    Spacer()
                    Spacer()
                }
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Feature Pills (blurry background)

    @ViewBuilder
    private func featurePills(geo: GeometryProxy) -> some View {
        let cx = geo.size.width / 2
        let cy = geo.size.height / 2

        Group {
            featurePill("chart.pie.fill", "Smart Reports", [Color(hex: "#10B981"), Color(hex: "#0EA5E9")])
                .offset(x: -cx * 0.55, y: pill1Y - cy * 0.22)

            featurePill("lock.shield.fill", "Bank-Level Security", [Color(hex: "#BF5AF2"), Color(hex: "#5E5CE6")])
                .offset(x: cx * 0.52, y: pill2Y + cy * 0.15)

            featurePill("calendar.badge.plus", "Apple Calendar", [Color(hex: "#F59E0B"), Color(hex: "#EF4444")])
                .offset(x: -cx * 0.35, y: pill3Y + cy * 0.32)

            featurePill("building.2.fill", "KDV / VAT Ready", [Color(hex: "#0EA5E9"), Color(hex: "#5E5CE6")])
                .offset(x: cx * 0.38, y: -cy * 0.40)
        }
        .opacity(pillOp)
    }

    private func featurePill(_ icon: String, _ label: String, _ colors: [Color]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.white.opacity(0.72))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        )
        .blur(radius: 0.5)
        .shadow(color: colors[0].opacity(0.25), radius: 10, y: 4)
    }

    // MARK: - Animation Sequence

    private func startAnimations() {
        // Logo
        withAnimation(.spring(response: 0.8, dampingFraction: 0.58).delay(0.08)) {
            logoScale = 1.0; logoOp = 1
        }
        // Rings
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.30)) {
            ringOp = 1; ringScale = 1.0
        }
        // Wordmark
        withAnimation(.spring(response: 0.55, dampingFraction: 0.68).delay(0.52)) {
            textOp = 1
        }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.68).delay(0.70)) {
            subOp = 1; subY = 0
        }
        // Pills
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.90)) {
            pillOp = 1
            pill1Y = 0; pill2Y = 0; pill3Y = 0
        }

        // Continuous loops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pulse = true; orbiting = true
        }

        // Halo rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false).delay(0.3)) {
            haloRotation = 360
        }
    }
}

// MARK: - Onboarding Carousel

struct OnboardingCarousel: View {
    var onComplete: () -> Void
    @State private var current = 0

    struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let gradient: [Color]
        let titleKey: String
        let subtitleKey: String
        let badge: String?
    }

    private let pages: [Page] = [
        Page(icon: "chart.line.uptrend.xyaxis",
             gradient: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
             titleKey: "onboarding.page1.title",
             subtitleKey: "onboarding.page1.subtitle",
             badge: nil),
        Page(icon: "building.2.crop.circle.fill",
             gradient: [Color(hex: "#0EA5E9"), Color(hex: "#5E5CE6")],
             titleKey: "onboarding.page2.title",
             subtitleKey: "onboarding.page2.subtitle",
             badge: "KDV / VAT"),
        Page(icon: "chart.pie.fill",
             gradient: [Color(hex: "#10B981"), Color(hex: "#0EA5E9")],
             titleKey: "onboarding.page3.title",
             subtitleKey: "onboarding.page3.subtitle",
             badge: "AI Powered"),
        Page(icon: "calendar.badge.plus",
             gradient: [Color(hex: "#F59E0B"), Color(hex: "#EF4444")],
             titleKey: "onboarding.page4.title",
             subtitleKey: "onboarding.page4.subtitle",
             badge: "Apple Calendar"),
        Page(icon: "lock.shield.fill",
             gradient: [Color(hex: "#BF5AF2"), Color(hex: "#5E5CE6")],
             titleKey: "onboarding.page5.title",
             subtitleKey: "onboarding.page5.subtitle",
             badge: "Encrypted"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $current) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                    OnboardingPageCard(page: page).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Controls
            VStack(spacing: 22) {
                // Dots
                HStack(spacing: 7) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == current ? Color.white : Color.white.opacity(0.26))
                            .frame(width: i == current ? 24 : 7, height: 7)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
                    }
                }

                // CTA
                Button {
                    Haptic.medium()
                    if current < pages.count - 1 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { current += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(current < pages.count - 1
                             ? NSLocalizedString("onboarding.continue", comment: "")
                             : NSLocalizedString("onboarding.getStarted", comment: ""))
                            .font(.system(size: 17, weight: .bold))
                        Image(systemName: current < pages.count - 1 ? "arrow.right" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(
                                colors: pages[current].gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                    )
                    .shadow(color: pages[current].gradient[0].opacity(0.60), radius: 20, y: 7)
                }
                .padding(.horizontal, 28)
                .buttonStyle(FABButtonStyle())

                if current < pages.count - 1 {
                    Button(NSLocalizedString("onboarding.skip", comment: "")) {
                        withAnimation { current = pages.count - 1 }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.38))
                }
            }
            .padding(.bottom, 54)
        }
    }
}

// MARK: - Onboarding Page Card

struct OnboardingPageCard: View {
    let page: OnboardingCarousel.Page
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                // Glow bloom
                Circle()
                    .fill(RadialGradient(
                        colors: [page.gradient[0].opacity(0.50), .clear],
                        center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200)
                    .blur(radius: 25)

                // Glass card icon
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 118, height: 118)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 0.7)
                        )
                        .shadow(color: page.gradient[0].opacity(0.55), radius: 32, y: 14)

                    Image(systemName: page.icon)
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: page.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                }
            }
            .scaleEffect(appeared ? 1 : 0.65)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 38)

            // Badge
            if let badge = page.badge {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.3)
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: page.gradient,
                        startPoint: .leading,
                        endPoint: .trailing))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(page.gradient[0].opacity(0.12))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(page.gradient[0].opacity(0.30), lineWidth: 0.5))
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .padding(.bottom, 14)
            }

            // Title
            Text(NSLocalizedString(page.titleKey, comment: ""))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

            Spacer().frame(height: 16)

            // Subtitle
            Text(NSLocalizedString(page.subtitleKey, comment: ""))
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color.white.opacity(0.58))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.70).delay(0.05)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }
}
