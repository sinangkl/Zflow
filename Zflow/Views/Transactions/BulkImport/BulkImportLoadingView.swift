import SwiftUI

struct BulkImportLoadingView: View {
    var body: some View {
        ZStack {
            MeshGradientBackground()
                .ignoresSafeArea()
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let date = timeline.date.timeIntervalSinceReferenceDate
                
                ZStack {
                    // 1. Foundation: Massive Soft Glow
                    LiquidBlob(color: AppTheme.baseColor.opacity(0.2), size: 400, speed: 0.3, offset: 40, date: date)
                        .blur(radius: 80)
                    
                    // 2. The "Liquid" Layers
                    LiquidBlob(color: AppTheme.baseColor.opacity(0.4), size: 280, speed: 0.8, offset: 20, date: date)
                    LiquidBlob(color: Color.white.opacity(0.15), size: 240, speed: 1.2, offset: 35, date: date + 1)
                    LiquidBlob(color: AppTheme.baseColor.opacity(0.3), size: 260, speed: 0.5, offset: 50, date: date + 2)
                    
                    // 3. Glass Shield
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 20)
                    
                    // 4. Core Icon with native pulse
                    Image(systemName: "sparkles")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, AppTheme.baseColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .versionedSymbolEffect(.pulse)
                        .shadow(color: AppTheme.baseColor.opacity(0.8), radius: 20)
                }
            }
            
            VStack {
                Spacer()
                VStack(spacing: 16) {
                    Text(NSLocalizedString("ai.analyzingTitle", comment: "Yapay Zeka dökümünüzü analiz ediyor..."))
                        .eliteSubheading()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("ai.loadingSub", comment: "İşlemleriniz akıllıca kategorize ediliyor."))
                        .eliteCaption()
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}

struct LiquidBlob: View {
    let color: Color
    let size: CGFloat
    let speed: Double
    let offset: CGFloat
    let date: Double
    
    var body: some View {
        let x = sin(date * speed) * offset
        let y = cos(date * speed * 0.8) * offset
        
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
            .blur(radius: 40)
            .scaleEffect(1 + sin(date * speed * 0.5) * 0.1)
    }
}

#Preview {
    BulkImportLoadingView()
}
