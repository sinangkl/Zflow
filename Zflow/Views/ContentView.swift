import SwiftUI

// MARK: - Content View
// Login → RootView geçiş: elegant spring + scale morph

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var animateTransition = false

    var body: some View {
        ZStack {
            if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.spring(response: 0.68, dampingFraction: 0.82)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.opacity)
                .zIndex(2)

            } else if authVM.isLoggedIn {
                RootView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 1.04)
                            .combined(with: .opacity)
                            .combined(with: .move(edge: .trailing)),
                        removal: .scale(scale: 0.96).combined(with: .opacity)))
                    .zIndex(1)

            } else {
                LoginView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.94).combined(with: .opacity)))
                    .zIndex(0)
            }
        }
        .animation(.spring(response: 0.60, dampingFraction: 0.82), value: authVM.isLoggedIn)
        .animation(.spring(response: 0.60, dampingFraction: 0.82), value: hasSeenOnboarding)
        .task { await authVM.checkSession() }
    }
}
