import SwiftUI
import Combine
import QuartzCore

// MARK: - Shared Gradient Animator (Singleton)
// Single CADisplayLink feeds ALL MeshGradientBackground instances.
// Eliminates per-view Timer overhead; tab switches cost zero.
// Pauses automatically when app is inactive to save battery.

@MainActor
final class GradientAnimator: ObservableObject {
    static let shared = GradientAnimator()
    @Published var t: CGFloat = 0

    private var link: CADisplayLink?
    private var isPlaying = false

    private init() { start() }

    func start() {
        guard link == nil else { return }
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        link?.add(to: .main, forMode: .common)
        isPlaying = true
    }
    
    func pause() {
        link?.isPaused = true
        isPlaying = false
    }
    
    func resume() {
        link?.isPaused = false
        isPlaying = true
    }

    func stop() {
        link?.invalidate()
        link = nil
        isPlaying = false
    }

    @objc private func tick(_ link: CADisplayLink) {
        t += 0.03
    }
}

// MARK: - MeshGradientBackground

public struct MeshGradientBackground: View {
    @ObservedObject private var animator = GradientAnimator.shared
    @Environment(\.colorScheme) var scheme
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("profileCardColor") private var appThemeColorHex: String = "#5E5CE6"

    public init() {}

    public var body: some View {
        let isDark = scheme == .dark
        let colors: [Color] = isDark ? darkColors : lightColors
        let meshPoints: [SIMD2<Float>] = buildMeshPoints(t: animator.t)

        // Base fill eliminates any black gaps at edges
        // MeshGradient is scaled 1.25× so animated edges stay off-screen
        ZStack {
            // Solid base — catches any pixel gaps at extreme animation phases
            (isDark ? baseColorDark : baseColorLight)
                .ignoresSafeArea()

            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 4,
                    height: 4,
                    points: meshPoints,
                    colors: colors
                )
                .scaleEffect(1.25) // Overscan — hides edge gaps during animation
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: isDark ? [
                        baseColorDark,
                        darkColors[1].opacity(0.85),
                        darkColors[2].opacity(0.75),
                        baseColorDark
                    ] : [
                        baseColorLight,
                        lightColors[1].opacity(0.85),
                        lightColors[3].opacity(0.75),
                        baseColorLight
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                animator.resume()
            } else {
                animator.pause()
            }
        }
    }

    // MARK: - Dynamic Colors (4×4 = 16)

    private var baseColorLight: Color {
        switch appThemeColorHex.uppercased() {
        case "#5E5CE6": return Color(hex: "#E8D5F5")
        case "#0A84FF": return Color(hex: "#E8F5FF")
        case "#30D158": return Color(hex: "#E5F5EC")
        case "#FF9F0A": return Color(hex: "#FFF5E0")
        case "#FF375F": return Color(hex: "#FFE5EC")
        case "#BF5AF2": return Color(hex: "#F2E5FF")
        case "#00C7BE": return Color(hex: "#E0FFFD")
        case "#FF6B6B": return Color(hex: "#FFE8E8")
        case "#FFD60A": return Color(hex: "#FFFCE0")
        case "#34D399": return Color(hex: "#E0FFF2")
        case "#FF3B30": return Color(hex: "#FFE5E0")
        case "#5AC8FA": return Color(hex: "#E4F7FF")
        default:        return Color(hex: appThemeColorHex).opacity(0.18)
        }
    }

    private var baseColorDark: Color {
        switch appThemeColorHex.uppercased() {
        case "#5E5CE6": return Color(hex: "#080820")
        case "#0A84FF": return Color(hex: "#061630")
        case "#30D158": return Color(hex: "#071C12")
        case "#FF9F0A": return Color(hex: "#1E0E00")
        case "#FF375F": return Color(hex: "#1E0610")
        case "#BF5AF2": return Color(hex: "#12062A")
        case "#00C7BE": return Color(hex: "#041C1A")
        case "#FF6B6B": return Color(hex: "#200808")
        case "#FFD60A": return Color(hex: "#1A1400")
        case "#34D399": return Color(hex: "#062018")
        case "#FF3B30": return Color(hex: "#200606")
        case "#5AC8FA": return Color(hex: "#061824")
        default:
            let uic = UIColor(Color(hex: appThemeColorHex))
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uic.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return Color(hue: Double(h), saturation: Double(max(s, 0.4)), brightness: 0.22)
        }
    }

    // Returns a 16-element color array from 4 theme colors using a rotating tile pattern.
    private func meshColors(_ c1: Color, _ c2: Color, _ c3: Color, _ c4: Color) -> [Color] {
        [c3, c2, c4, c1,
         c2, c4, c1, c3,
         c4, c1, c3, c2,
         c1, c3, c2, c4]
    }

    private var darkColors: [Color] {
        switch appThemeColorHex.uppercased() {
        case "#5E5CE6": // Indigo (default / logo)
            return meshColors(Color(hex: "#080820"), Color(hex: "#2E0E6B"), Color(hex: "#0B1850"), Color(hex: "#4D1590"))
        case "#0A84FF": // Blue
            return meshColors(Color(hex: "#061630"), Color(hex: "#0C3A80"), Color(hex: "#091E52"), Color(hex: "#1254B8"))
        case "#30D158": // Green
            return meshColors(Color(hex: "#071C12"), Color(hex: "#0E4A28"), Color(hex: "#09281A"), Color(hex: "#1A6638"))
        case "#FF9F0A": // Orange
            return meshColors(Color(hex: "#1E0E00"), Color(hex: "#5E2C00"), Color(hex: "#2E1600"), Color(hex: "#8C4800"))
        case "#FF375F": // Pink
            return meshColors(Color(hex: "#1E0610"), Color(hex: "#5C0E28"), Color(hex: "#2E081A"), Color(hex: "#8C1840"))
        case "#BF5AF2": // Purple
            return meshColors(Color(hex: "#12062A"), Color(hex: "#36086C"), Color(hex: "#1A083C"), Color(hex: "#5C189E"))
        case "#00C7BE": // Teal
            return meshColors(Color(hex: "#041C1A"), Color(hex: "#005C56"), Color(hex: "#062E2C"), Color(hex: "#008C84"))
        case "#FF6B6B": // Coral
            return meshColors(Color(hex: "#200808"), Color(hex: "#5C1414"), Color(hex: "#300E0E"), Color(hex: "#8C2828"))
        case "#FFD60A": // Gold
            return meshColors(Color(hex: "#1A1400"), Color(hex: "#5C4400"), Color(hex: "#2A1E00"), Color(hex: "#8C6800"))
        case "#34D399": // Mint
            return meshColors(Color(hex: "#062018"), Color(hex: "#105C3E"), Color(hex: "#0A2E24"), Color(hex: "#1E8C5E"))
        case "#FF3B30": // Red
            return meshColors(Color(hex: "#200606"), Color(hex: "#5C1010"), Color(hex: "#300C0C"), Color(hex: "#8C2020"))
        case "#5AC8FA": // Sky/Cyan
            return meshColors(Color(hex: "#061824"), Color(hex: "#0E4A72"), Color(hex: "#082438"), Color(hex: "#1870AA"))
        default:
            let base = Color(hex: appThemeColorHex)
            return meshColors(baseColorDark, base.opacity(0.4), base.opacity(0.2), baseColorDark.opacity(0.8))
        }
    }

    private var lightColors: [Color] {
        switch appThemeColorHex.uppercased() {
        case "#5E5CE6": // Indigo (default / logo)
            return meshColors(Color(hex: "#FAF9FF"), Color(hex: "#E8D5F5"), Color(hex: "#D0F0F7"), Color(hex: "#C8E6C9"))
        case "#0A84FF": // Blue
            return meshColors(Color(hex: "#F0F8FF"), Color(hex: "#D0E8FF"), Color(hex: "#E8F5FF"), Color(hex: "#C5DFFF"))
        case "#30D158": // Green
            return meshColors(Color(hex: "#F0FFF5"), Color(hex: "#C8EDDA"), Color(hex: "#E5F5EC"), Color(hex: "#D0F5E5"))
        case "#FF9F0A": // Orange
            return meshColors(Color(hex: "#FFFAF0"), Color(hex: "#FFE8C0"), Color(hex: "#FFF5E0"), Color(hex: "#FFDEA8"))
        case "#FF375F": // Pink
            return meshColors(Color(hex: "#FFF5F8"), Color(hex: "#FFCCD8"), Color(hex: "#FFE5EC"), Color(hex: "#FFD0DC"))
        case "#BF5AF2": // Purple
            return meshColors(Color(hex: "#F8F0FF"), Color(hex: "#E8D0FF"), Color(hex: "#F2E5FF"), Color(hex: "#DDBCFF"))
        case "#00C7BE": // Teal
            return meshColors(Color(hex: "#F0FFFF"), Color(hex: "#C8F5F4"), Color(hex: "#E0FFFD"), Color(hex: "#B8F0EE"))
        case "#FF6B6B": // Coral
            return meshColors(Color(hex: "#FFF5F5"), Color(hex: "#FFD0D0"), Color(hex: "#FFE8E8"), Color(hex: "#FFBEBE"))
        case "#FFD60A": // Gold
            return meshColors(Color(hex: "#FFFEEF"), Color(hex: "#FFF8C0"), Color(hex: "#FFFCE0"), Color(hex: "#FFF3A8"))
        case "#34D399": // Mint
            return meshColors(Color(hex: "#F0FFF8"), Color(hex: "#C8FFE8"), Color(hex: "#E0FFF2"), Color(hex: "#BAFADE"))
        case "#FF3B30": // Red
            return meshColors(Color(hex: "#FFF5F4"), Color(hex: "#FFCCC8"), Color(hex: "#FFE5E0"), Color(hex: "#FFB8B0"))
        case "#5AC8FA": // Sky/Cyan
            return meshColors(Color(hex: "#F0FAFF"), Color(hex: "#C8EEFF"), Color(hex: "#E4F7FF"), Color(hex: "#B8E8FF"))
        default:
            let base = Color(hex: appThemeColorHex)
            return meshColors(Color.white.opacity(0.5), base.opacity(0.15), baseColorLight, base.opacity(0.08))
        }
    }

    // MARK: - Mesh Point Builder

    private func buildMeshPoints(t: CGFloat) -> [SIMD2<Float>] {
        let amp: Float = 0.12   // reduced from 0.18 — smoother, less edge escape
        let f = Float(t)

        return [
            // Row 0 — static top edge
            SIMD2<Float>(0.00, 0.00),
            SIMD2<Float>(0.33, 0.00),
            SIMD2<Float>(0.67, 0.00),
            SIMD2<Float>(1.00, 0.00),

            // Row 1 — animated (~7 s cycle)
            SIMD2<Float>(
                clamp(0.0 + sin(f * 0.85) * amp),
                0.33 + cos(f * 0.70) * amp * 0.6),
            SIMD2<Float>(
                0.33 + sin(f * 1.00) * amp * 0.7,
                0.30 + sin(f * 0.90) * amp * 0.6),
            SIMD2<Float>(
                0.67 + cos(f * 0.75) * amp * 0.7,
                0.36 + cos(f * 1.10) * amp * 0.6),
            SIMD2<Float>(
                clamp(1.0 + sin(f * 0.65) * amp),
                0.33 + sin(f * 0.80) * amp * 0.6),

            // Row 2 — animated (offset phase ~8 s)
            SIMD2<Float>(
                clamp(0.0 + cos(f * 0.72) * amp),
                0.67 + sin(f * 0.80) * amp * 0.6),
            SIMD2<Float>(
                0.33 + cos(f * 0.90) * amp * 0.7,
                0.70 + cos(f * 0.75) * amp * 0.6),
            SIMD2<Float>(
                0.67 + sin(f * 0.80) * amp * 0.7,
                0.64 + sin(f * 0.95) * amp * 0.6),
            SIMD2<Float>(
                clamp(1.0 + cos(f * 0.60) * amp),
                0.67 + cos(f * 0.70) * amp * 0.6),

            // Row 3 — static bottom edge
            SIMD2<Float>(0.00, 1.00),
            SIMD2<Float>(0.33, 1.00),
            SIMD2<Float>(0.67, 1.00),
            SIMD2<Float>(1.00, 1.00)
        ]
    }

    /// Clamp point coordinate to 0.0...1.0 range
    private func clamp(_ v: Float) -> Float {
        min(max(v, 0.0), 1.0)
    }
}
