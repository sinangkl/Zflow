import SwiftUI

struct ZFlowLockScreen: View {
    @ObservedObject var securityMgr = ZFlowSecurityManager.shared
    
    var body: some View {
        ZStack {
            // Blurred background to hide financial data
            MeshGradientBackground()
                .blur(radius: 20)
                .ignoresSafeArea()
            
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(ZColor.indigo.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(ZColor.indigo)
                }
                
                VStack(spacing: 12) {
                    Text("ZFlow is Locked")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Authenticate to access your finances")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Unlock Button
                Button {
                    securityMgr.authenticate { _ in }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: securityMgr.canEvaluateBiometrics ? "faceid" : "key.fill")
                        Text("Unlock App")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ZColor.indigo)
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                }
                
                Spacer().frame(height: 50)
            }
        }
        .transition(.opacity)
        .zIndex(999)
    }
}
