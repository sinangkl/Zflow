import SwiftUI

// MARK: - Bank Connection View
// Yapı Kredi Open Banking entegrasyonu — hesap bağlama ve yönetim ekranı

struct BankConnectionView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) var scheme
    @Environment(\.dismiss) var dismiss

    @State private var connectedBanks: [ConnectedBank] = []
    @State private var isLoading = false
    @State private var showAddBank = false

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero banner
                        heroBanner

                        // Connected banks
                        if connectedBanks.isEmpty {
                            emptyState
                        } else {
                            connectedBanksSection
                        }

                        // Supported banks
                        supportedBanksSection

                        // Security note
                        securityNote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(NSLocalizedString("bank.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        GradientCard(gradient: LinearGradient(
            colors: [Color(hex: "#059669"), Color(hex: "#10B981"), Color(hex: "#34D399")],
            startPoint: .topLeading, endPoint: .bottomTrailing)) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 6) {
                        Text(NSLocalizedString("bank.heroTitle", comment: ""))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text(NSLocalizedString("bank.heroSubtitle", comment: ""))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.80))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(ZColor.indigo.opacity(0.4))

            Text(NSLocalizedString("bank.noAccounts", comment: ""))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showAddBank = true
                Haptic.medium()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text(NSLocalizedString("bank.connectAccount", comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.accentGradient)
                )
            }
            .buttonStyle(FABButtonStyle())
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(scheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }

    // MARK: - Connected Banks

    private var connectedBanksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("bank.connectedAccounts", comment: "").uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(connectedBanks.enumerated()), id: \.element.id) { idx, bank in
                    connectedBankRow(bank)
                    if idx < connectedBanks.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(scheme == .dark ? Color(.systemGray6) : .white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Add another bank
            Button {
                showAddBank = true
                Haptic.light()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text(NSLocalizedString("bank.addAnother", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ZColor.indigo)
                .padding(.leading, 6)
                .padding(.top, 4)
            }
        }
    }

    private func connectedBankRow(_ bank: ConnectedBank) -> some View {
        HStack(spacing: 14) {
            // Bank icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(bank.bankColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: bank.bankIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(bank.bankColor)
            }

            // Bank info
            VStack(alignment: .leading, spacing: 3) {
                Text(bank.bankName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(bank.maskedAccountNo)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status
            HStack(spacing: 4) {
                Circle()
                    .fill(bank.isActive ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(bank.isActive
                     ? NSLocalizedString("bank.statusActive", comment: "")
                     : NSLocalizedString("bank.statusPending", comment: ""))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(bank.isActive ? .green : .orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Supported Banks

    private var supportedBanksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("bank.supportedBanks", comment: "").uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(SupportedBank.allBanks) { bank in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(bank.color.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: bank.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(bank.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(bank.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text(bank.status)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if bank.isAvailable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 18))
                        } else {
                            Text(NSLocalizedString("bank.comingSoon", comment: ""))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(Color(.systemGray5)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if bank.id != SupportedBank.allBanks.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(scheme == .dark ? Color(.systemGray6) : .white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Security Note

    private var securityNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 24))
                .foregroundColor(ZColor.indigo.opacity(0.6))

            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("bank.securityTitle", comment: ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(NSLocalizedString("bank.securitySubtitle", comment: ""))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ZColor.indigo.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ZColor.indigo.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Data Models

struct ConnectedBank: Identifiable {
    let id: UUID
    let bankName: String
    let maskedAccountNo: String
    let bankIcon: String
    let bankColor: Color
    let isActive: Bool
}

struct SupportedBank: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let status: String
    let isAvailable: Bool

    static let allBanks: [SupportedBank] = [
        SupportedBank(id: "yapikredi", name: "Yapı Kredi", icon: "building.columns.fill",
                      color: Color(hex: "#1A237E"), status: "Açık Bankacılık API", isAvailable: true),
        SupportedBank(id: "garanti", name: "Garanti BBVA", icon: "building.columns.fill",
                      color: Color(hex: "#00695C"), status: "Yakında", isAvailable: false),
        SupportedBank(id: "isbank", name: "İş Bankası", icon: "building.columns.fill",
                      color: Color(hex: "#1565C0"), status: "Yakında", isAvailable: false),
        SupportedBank(id: "akbank", name: "Akbank", icon: "building.columns.fill",
                      color: Color(hex: "#C62828"), status: "Yakında", isAvailable: false),
        SupportedBank(id: "ziraat", name: "Ziraat Bankası", icon: "building.columns.fill",
                      color: Color(hex: "#2E7D32"), status: "Yakında", isAvailable: false),
        SupportedBank(id: "halkbank", name: "Halkbank", icon: "building.columns.fill",
                      color: Color(hex: "#0D47A1"), status: "Yakında", isAvailable: false),
    ]
}
