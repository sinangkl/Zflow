import SwiftUI
import PhotosUI

struct ThemeSettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var familyVM: FamilyViewModel
    @EnvironmentObject var walletVM: WalletPassManager
    @Environment(\.dismiss) var dismiss

    @AppStorage("appColorScheme") private var appColorScheme: String = "system"

    @State private var profileCardColor = "#5E5CE6"
    @State private var familyCardColor = "#FF6B6B"
    @State private var walletCardColor = "#5E5CE6"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let presetColors: [(hex: String, name: String)] = [
        ("#5E5CE6", "İndigo"),
        ("#0A84FF", "Mavi"),
        ("#30D158", "Yeşil"),
        ("#FF9F0A", "Turuncu"),
        ("#FF375F", "Pembe"),
        ("#BF5AF2", "Mor"),
        ("#00C7BE", "Turkuaz"),
        ("#FF6B6B", "Mercan"),
        ("#FF3B30", "Kırmızı"),
        ("#1A1A1A", "Koyu"),
        ("#FFD60A", "Altın"),
        ("#5AC8FA", "Gökyüzü")
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MeshGradientBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. App Theme
                        themeSection(title: "UYGULAMA TEMASI", icon: "iphone") {
                            Picker("Tema", selection: $appColorScheme) {
                                Text("Sistem").tag("system")
                                Text("Açık").tag("light")
                                Text("Koyu").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 8)
                        }

                        // 2. Profile Card Theme
                        themeSection(title: "PROFİL KARTI", icon: "person.crop.circle.fill") {
                            MiniWalletCard(
                                color: Color(hex: profileCardColor),
                                name: authVM.userProfile?.fullName ?? "Kullanıcı",
                                label: "Profil"
                            )
                            colorGrid(selection: $profileCardColor)
                        }

                        // 3. Family Card Theme
                        themeSection(title: "AİLE KARTI", icon: "house.fill") {
                            MiniWalletCard(
                                color: Color(hex: familyCardColor),
                                name: familyVM.family?.name ?? "Aile Grubu",
                                label: "Aile"
                            )
                            colorGrid(selection: $familyCardColor)
                        }

                        // 4. Wallet Card Theme (Temporarily Disabled)
                        themeSection(title: "APPLE WALLET (YAKINDA)", icon: "wallet.pass.fill") {
                            MiniWalletCard(
                                color: Color(hex: walletCardColor),
                                name: "ZFlow Cüzdanı",
                                label: "Cüzdan"
                            )
                            .opacity(0.5)
                            colorGrid(selection: $walletCardColor)
                                .disabled(true)
                                .opacity(0.5)
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                Text("Bu özellik yakında aktif edilecektir.")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 110)
                }

                // Sticky Save Button
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        saveThemes()
                    } label: {
                        ZStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Label("Değişiklikleri Kaydet", systemImage: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isSaving ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(AppTheme.accentGradient))
                        )
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
                .padding(.bottom, 0)
            }
            .navigationTitle("Tema & Görünüm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.primary.opacity(0.08)))
                    }
                }
            }
            .onAppear(perform: loadCurrentThemes)
            .alert("Hata", isPresented: $showError) {
                Button("Tamam") { showError = false }
            } message: {
                Text(errorMessage ?? "Bilinmeyen hata oluştu")
            }
        }
    }

    private func themeSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 4)

            GlassCard(cornerRadius: 20) {
                VStack(spacing: 16) {
                    content()
                }
                .padding(16)
            }
        }
    }

    private func colorGrid(selection: Binding<String>) -> some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 6)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(presetColors, id: \.hex) { color in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection.wrappedValue = color.hex
                    }
                    Haptic.selection()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: color.hex))
                            .frame(width: 36, height: 36)
                        if selection.wrappedValue == color.hex {
                            Circle()
                                .stroke(Color.primary, lineWidth: 2.5)
                                .padding(-4)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadCurrentThemes() {
        profileCardColor = UserDefaults.standard.string(forKey: "profileCardColor") ?? "#5E5CE6"
        familyCardColor = UserDefaults.standard.string(forKey: "familyCardColor")
            ?? authVM.userProfile?.themeFamilyCardHex ?? "#FF6B6B"
        walletCardColor = UserDefaults.standard.string(forKey: "walletCardColor")
            ?? authVM.userProfile?.themeWalletCardHex ?? "#5E5CE6"
    }

    private func saveThemes() {
        isSaving = true
        Task {
            // 1. Save locally first — always succeeds
            UserDefaults.standard.set(profileCardColor, forKey: "profileCardColor")
            UserDefaults.standard.set(familyCardColor, forKey: "familyCardColor")
            UserDefaults.standard.set(walletCardColor, forKey: "walletCardColor")

            // 2. Update Apple Wallet pass (Temporarily Removed)
            // walletVM.generateAndAddPass(...)

            isSaving = false
            Haptic.success()
            dismiss()

            // 3. Sync to server in background (non-blocking, independent operations)
            async let profileSync: Bool = authVM.updateProfileThemes(
                appTheme: appColorScheme,
                familyHex: familyCardColor,
                walletHex: walletCardColor
            )

            if let familyId = familyVM.family?.id,
               let adminId = authVM.currentUserId,
               familyVM.members.first(where: { $0.userId == authVM.currentUserId })?.role == "admin" {
                await familyVM.updateFamilySettings(
                    familyId: familyId,
                    adminId: adminId,
                    name: familyVM.family!.name,
                    colorHex: familyCardColor
                )
            }

            _ = await profileSync
        }
    }
}

// MARK: - Mini Wallet Card Preview

struct MiniWalletCard: View {
    let color: Color
    let name: String
    let label: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Decorative circles
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 120, height: 120)
                            .offset(x: 140, y: -30)
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 80, height: 80)
                            .offset(x: 160, y: 40)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                )
                .shadow(color: color.opacity(0.45), radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 0) {
                // Top row
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "z.circle.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.white)
                        Text("ZFlow")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }

                Spacer()

                // Chip icon
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 24)
                    .padding(.bottom, 6)

                // Name
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Card number dots
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { _ in
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: color)
    }
}
