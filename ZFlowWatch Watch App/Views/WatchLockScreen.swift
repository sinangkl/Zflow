import SwiftUI

struct WatchLockScreen: View {
    @ObservedObject var securityMgr = ZFlowSecurityManager.shared
    
    var body: some View {
        ZStack {
            // Dark blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(wAccent)
                
                Text("Locked")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                
                Button {
                    securityMgr.authenticate { _ in }
                } label: {
                    Text("Unlock")
                        .fontWeight(.bold)
                }
                .tint(wAccent)
                .padding(.horizontal, 20)
            }
        }
        .transition(.opacity)
        .zIndex(999)
    }
}
