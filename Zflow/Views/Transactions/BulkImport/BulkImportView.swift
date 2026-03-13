import SwiftUI

struct BulkImportView: View {
    @StateObject var viewModel: BulkImportViewModel
    @EnvironmentObject var authVM: AuthViewModel
    let fileURL: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle, .analyzing:
                BulkImportLoadingView()
            case .verifying:
                BulkImportVerificationView(viewModel: viewModel, transactions: $viewModel.transactions)
            case .saving:
                savingView
            case .completed(let count):
                completedView(count: count)
            case .error(let message):
                errorView(message: message)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: String(describing: viewModel.state))
        .onAppear {
            if case .idle = viewModel.state {
                guard let uid = authVM.currentUserId?.uuidString else {
                    viewModel.state = .error("Oturum hatası: Kullanıcı ID bulunamadı.")
                    return
                }
                viewModel.processFile(url: fileURL, userId: uid)
            }
        }
    }
    
    private var savingView: some View {
        ZStack {
            MeshGradientBackground()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            
            VStack(spacing: 32) {
                ProgressView()
                    .tint(AppTheme.baseColor)
                    .scaleEffect(1.8)
                    .glow(color: AppTheme.baseColor.opacity(0.3), radius: 20)
                
                Text(NSLocalizedString("bulk.saving", comment: "İşlemleriniz kaydediliyor..."))
                    .eliteSubheading()
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private func completedView(count: Int) -> some View {
        ZStack {
            MeshGradientBackground()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            
            VStack(spacing: 40) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentGradient)
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                        .opacity(0.2)
                    
                    Circle()
                        .stroke(AppTheme.accentGradient, lineWidth: 2)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AppTheme.accentGradient)
                        .versionedSymbolEffect(.bounce)
                }
                
                VStack(spacing: 12) {
                    Text(NSLocalizedString("bulk.doneTitle", comment: "Başarılı!"))
                        .eliteTitle()
                        .foregroundStyle(.primary)
                    
                    Text(String(format: NSLocalizedString("bulk.doneSub", comment: "%d işlem başarıyla içe aktarıldı."), count))
                        .eliteFont(size: 16, weight: .medium, textStyle: .body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button {
                    Haptic.success()
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.done", comment: "Bitti"))
                        .eliteFont(size: 17, weight: .bold, textStyle: .body)
                        .frame(width: 240, height: 56)
                        .background(AppTheme.gold)
                        .foregroundStyle(AppTheme.burgundy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .glow(color: ZColor.gold.opacity(0.4), radius: 10)
                }
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        ZStack {
            MeshGradientBackground()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                    .versionedSymbolEffect(.pulse)
                
                Text(message)
                    .eliteFont(size: 16, weight: .semibold, textStyle: .body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(NSLocalizedString("common.cancel", comment: "İptal")) {
                    dismiss()
                }
                .eliteFont(size: 15, weight: .bold, textStyle: .body)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
            }
        }
    }
}
