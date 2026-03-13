import SwiftUI
import Supabase
import PostgREST

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: Color(hex: "#F59E0B").opacity(0.5), radius: 20, y: 10)
                            .padding(.top, 40)
                        
                        Text("ZFlow Premium")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(ZColor.label)
                        
                        Text("Tüm limitleri kaldırın ve gelişmiş finansal araçlara erişin.")
                            .font(.system(size: 16))
                            .foregroundColor(ZColor.labelSec)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        
                        VStack(spacing: 16) {
                            featureRow(icon: "infinity", text: "Sınırsız Bütçe Yönetimi")
                            featureRow(icon: "person.3.fill", text: "Gelişmiş Aile Paylaşımı")
                            featureRow(icon: "chart.pie.fill", text: "Detaylı Raporlar")
                            featureRow(icon: "sparkles", text: "Özel Temalar")
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                        
                        Spacer(minLength: 40)
                        
                        Button {
                            // Dummy purchase action for now
                            isLoading = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                Task {
                                    // Update locally for testing
                                    if let uid = authVM.currentUserId {
                                        _ = try? await SupabaseManager.shared.client
                                            .from("profiles")
                                            .update(["subscription_tier": "premium"])
                                            .eq("id", value: uid.uuidString)
                                            .execute()
                                        await authVM.fetchProfile()
                                    }
                                    isLoading = false
                                    dismiss()
                                    Haptic.success()
                                }
                            }
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Premium'a Yükselt")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color(hex: "#F59E0B").opacity(0.4), radius: 15, y: 5)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 30)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Daha Sonra")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(ZColor.labelSec)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#F59E0B"))
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ZColor.label)
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
