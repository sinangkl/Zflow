import SwiftUI

struct FamilyScannerView: View {
    @Environment(\.dismiss) var dismiss
    
    // In a real device scenario, this could use CodeScanner or AVFoundation.
    // Since this is primarily to demonstrate the UI and permissions flow:
    
    @State private var isScanning = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    Text("QR Kodu Çerçeveye Yerleştirin")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Davet linkini otomatik olarak algılayacağız.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    ZStack {
                        // Scanner UI Overlay
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppTheme.baseColor, style: StrokeStyle(lineWidth: 4, dash: [40, 40], dashPhase: isScanning ? 80 : 0))
                            .frame(width: 250, height: 250)
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isScanning)
                        
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 250, height: 250)
                    }
                    .padding(.vertical, 30)
                    
                    Spacer()
                    
                    Button {
                        Haptic.selection()
                        dismiss()
                    } label: {
                        Text("İptal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.2)))
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                isScanning = true
            }
        }
    }
}
