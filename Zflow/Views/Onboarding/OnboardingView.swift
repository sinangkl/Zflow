import SwiftUI

// MARK: - Onboarding Coordinator

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var stage = 0   // 0 = splash  1 = carousel

    var body: some View {
        ZStack {
            MeshGradientBackground()
                .ignoresSafeArea()

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


// MARK: - ZFlow Splash
// World-class reveal. Fully adaptive for light & dark mode.

struct ZFlowSplash: View {
    @Environment(\.colorScheme) var scheme

    @State private var logoScale:    CGFloat = 0.18
    @State private var logoOp:       Double  = 0
    @State private var ringOp:       Double  = 0
    @State private var ringScale:    CGFloat = 0.6
    @State private var textOp:       Double  = 0
    @State private var subOp:        Double  = 0
    @State private var subY:         CGFloat = 24
    @State private var pulse                 = false
    @State private var orbiting              = false
    @State private var haloRotation: Double  = 0

    // Floating feature pills
    @State private var pill1Y: CGFloat = 60
    @State private var pill2Y: CGFloat = -60
    @State private var pill3Y: CGFloat = 80
    @State private var pillOp: Double  = 0

    // ── Adaptive colours ──────────────────────────────────────────────

    private var base:     Color { AppTheme.baseColor }
    private var baseAlt:  Color { AppTheme.accentSecondary }

    /// "ZFlow" wordmark gradient
    private var titleGradient: LinearGradient {
        scheme == .dark
            ? LinearGradient(
                colors: [.white, Color(hex: "#E8E4FF"), base.opacity(0.80)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(
                colors: [base, baseAlt],
                startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Tagline / subtitle color
    private var subtitleColor: Color {
        scheme == .dark ? Color.white.opacity(0.50) : Color(.secondaryLabel)
    }

    /// Logo icon gradient
    private var iconGradient: LinearGradient {
        scheme == .dark
            ? LinearGradient(colors: [.white, Color(hex: "#C4B5FD")], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [base, baseAlt], startPoint: .top, endPoint: .bottom)
    }

    /// Glass circle fill
    private var glassFill: AnyShapeStyle {
        scheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.92))
    }

    /// Glass circle stroke
    private var glassBorder: LinearGradient {
        scheme == .dark
            ? LinearGradient(
                colors: [Color.white.opacity(0.45), Color.white.opacity(0.05), base.opacity(0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(
                colors: [Color.white, base.opacity(0.38)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Inner dashed ring stroke
    private var dashedRingGradient: LinearGradient {
        scheme == .dark
            ? LinearGradient(
                colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(
                colors: [base.opacity(0.22), base.opacity(0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Feature pills floating in background
                featurePills(geo: geo)

                VStack(spacing: 0) {
                    Spacer()

                    // ── Logo assembly ─────────────────────────────────
                    ZStack {
                        // Outer glow halo
                        Circle()
                            .fill(RadialGradient(
                                colors: [base.opacity(scheme == .dark ? 0.38 : 0.20), .clear],
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
                                        base.opacity(scheme == .dark ? 0.90 : 0.70),
                                        baseAlt.opacity(scheme == .dark ? 0.60 : 0.40),
                                        .clear,
                                        base.opacity(scheme == .dark ? 0.90 : 0.70),
                                    ],
                                    center: .center),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .frame(width: 148)
                            .rotationEffect(.degrees(haloRotation))
                            .opacity(ringOp)

                        // Inner dashed ring
                        Circle()
                            .stroke(
                                dashedRingGradient,
                                style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                            .frame(width: 118)
                            .rotationEffect(.degrees(-haloRotation * 0.5))
                            .opacity(ringOp * 0.6)

                        // Pulse rings (3 layers)
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(
                                    base.opacity(
                                        (scheme == .dark ? 0.30 : 0.18) - Double(i) * 0.06),
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
                                .fill(baseAlt)
                                .frame(width: 7, height: 7)
                                .shadow(color: base, radius: 6)
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
                                .fill(glassFill)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .strokeBorder(glassBorder, lineWidth: 0.8)
                                )
                                .shadow(color: base.opacity(scheme == .dark ? 0.80 : 0.35), radius: 40, y: 16)
                                .shadow(color: base.opacity(scheme == .dark ? 0.20 : 0.10), radius: 8, y: 4)

                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(iconGradient)
                        }
                        .scaleEffect(logoScale)
                        .opacity(logoOp)
                    }

                    Spacer().frame(height: 38)

                    // ── Wordmark ──────────────────────────────────────
                    VStack(spacing: 10) {
                        Text("ZFlow")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(titleGradient)
                            .tracking(-1.2)
                            .shadow(color: base.opacity(scheme == .dark ? 0.40 : 0.16), radius: 10, y: 4)
                            .opacity(textOp)

                        Text(NSLocalizedString("onboarding.tagline", comment: ""))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(subtitleColor)
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

    // MARK: - Feature Pills ────────────────────────────────────────────

    @ViewBuilder
    private func featurePills(geo: GeometryProxy) -> some View {
        let cx = geo.size.width / 2
        let cy = geo.size.height / 2

        Group {
            featurePill("chart.pie.fill", "Smart Reports",
                        [Color(hex: "#10B981"), Color(hex: "#0EA5E9")])
                .offset(x: -cx * 0.55, y: pill1Y - cy * 0.22)

            featurePill("lock.shield.fill", "Bank-Level Security",
                        [Color(hex: "#BF5AF2"), base])
                .offset(x: cx * 0.52, y: pill2Y + cy * 0.15)

            featurePill("calendar.badge.plus", "Apple Calendar",
                        [Color(hex: "#F59E0B"), Color(hex: "#EF4444")])
                .offset(x: -cx * 0.35, y: pill3Y + cy * 0.32)

            featurePill("building.2.fill", "KDV / VAT Ready",
                        [Color(hex: "#0EA5E9"), base])
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
                .foregroundColor(scheme == .dark
                    ? Color.white.opacity(0.72)
                    : Color.primary.opacity(0.70))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(scheme == .dark
                      ? AnyShapeStyle(.ultraThinMaterial)
                      : AnyShapeStyle(Color.white.opacity(0.88)))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            scheme == .dark
                                ? Color.white.opacity(0.12)
                                : Color.black.opacity(0.07),
                            lineWidth: 0.5))
        )
        .blur(radius: 0.4)
        .shadow(color: colors[0].opacity(scheme == .dark ? 0.25 : 0.15), radius: 10, y: 4)
    }

    // MARK: - Animation Sequence ───────────────────────────────────────

    private func startAnimations() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.58).delay(0.08)) {
            logoScale = 1.0; logoOp = 1
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.30)) {
            ringOp = 1; ringScale = 1.0
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.68).delay(0.52)) {
            textOp = 1
        }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.68).delay(0.70)) {
            subOp = 1; subY = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.90)) {
            pillOp = 1
            pill1Y = 0; pill2Y = 0; pill3Y = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pulse = true; orbiting = true
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false).delay(0.3)) {
            haloRotation = 360
        }
    }
}


// MARK: - Onboarding Carousel

struct OnboardingCarousel: View {
    var onComplete: () -> Void
    @Environment(\.colorScheme) var scheme
    @State private var current = 0

    struct Page: Identifiable {
        let id        = UUID()
        let icon:      String
        let gradient: [Color]
        let titleKey:  String
        let subtitleKey: String
        let badge:     String?
    }

    private let pages: [Page] = [
        Page(icon: "chart.line.uptrend.xyaxis",
             gradient: [AppTheme.baseColor, AppTheme.accentSecondary],
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

            // ── Controls
            VStack(spacing: 22) {

                // Progress dots
                HStack(spacing: 7) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == current
                                  ? (scheme == .dark ? Color.white : pages[current].gradient[0])
                                  : (scheme == .dark ? Color.white.opacity(0.26) : pages[current].gradient[0].opacity(0.28)))
                            .frame(width: i == current ? 24 : 7, height: 7)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
                    }
                }

                // CTA button
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(
                                    colors: pages[current].gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                            // Inner highlight
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color.white.opacity(0.18), .clear],
                                    startPoint: .top, endPoint: .center))
                        }
                    )
                    .shadow(color: pages[current].gradient[0].opacity(0.55), radius: 20, y: 7)
                }
                .padding(.horizontal, 28)
                .buttonStyle(FABButtonStyle())

                // Skip
                if current < pages.count - 1 {
                    Button(NSLocalizedString("onboarding.skip", comment: "")) {
                        withAnimation { current = pages.count - 1 }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(scheme == .dark ? Color.white.opacity(0.38) : Color(.secondaryLabel))
                }
            }
            .padding(.bottom, 54)
        }
    }
}


// MARK: - Onboarding Page Card

struct OnboardingPageCard: View {
    let page: OnboardingCarousel.Page
    @Environment(\.colorScheme) var scheme
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Icon ──────────────────────────────────────────────────
            ZStack {
                // Glow bloom
                Circle()
                    .fill(RadialGradient(
                        colors: [page.gradient[0].opacity(scheme == .dark ? 0.50 : 0.30), .clear],
                        center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200)
                    .blur(radius: 25)

                // Glass icon card
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(scheme == .dark
                              ? AnyShapeStyle(.ultraThinMaterial)
                              : AnyShapeStyle(Color.white.opacity(0.90)))
                        .frame(width: 118, height: 118)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: scheme == .dark
                                            ? [Color.white.opacity(0.28), Color.white.opacity(0.04)]
                                            : [Color.white, page.gradient[0].opacity(0.20)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 0.7)
                        )
                        .shadow(
                            color: page.gradient[0].opacity(scheme == .dark ? 0.55 : 0.28),
                            radius: 32, y: 14)

                    Image(systemName: page.icon)
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(LinearGradient(
                            colors: page.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                }
            }
            .scaleEffect(appeared ? 1 : 0.65)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 38)

            // ── Badge ─────────────────────────────────────────────────
            if let badge = page.badge {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.3)
                }
                .foregroundStyle(LinearGradient(
                    colors: page.gradient,
                    startPoint: .leading,
                    endPoint: .trailing))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(page.gradient[0].opacity(scheme == .dark ? 0.12 : 0.10))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(page.gradient[0].opacity(scheme == .dark ? 0.30 : 0.35),
                                              lineWidth: 0.5))
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .padding(.bottom, 14)
            }

            // ── Title ─────────────────────────────────────────────────
            Text(NSLocalizedString(page.titleKey, comment: ""))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(scheme == .dark ? .white : .primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

            Spacer().frame(height: 16)

            // ── Subtitle ──────────────────────────────────────────────
            Text(NSLocalizedString(page.subtitleKey, comment: ""))
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(scheme == .dark ? Color.white.opacity(0.58) : Color(.secondaryLabel))
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
