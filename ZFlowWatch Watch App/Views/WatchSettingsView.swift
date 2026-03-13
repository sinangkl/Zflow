import SwiftUI
import WatchKit

struct WatchSettingsView: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject var securityManager = ZFlowSecurityManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Profile Section
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(wAccent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(wAccent)
                    }
                    Text(store.snapshot.userDisplayName)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text(store.snapshot.userType.capitalized)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

                Divider().opacity(0.5)

                // Info Section
                VStack(alignment: .leading, spacing: 10) {
                    settingRow(icon: "iphone.radiowaves.left.and.right", 
                               label: Localizer.shared.l("watch.connection"), 
                               value: store.isConnected ? Localizer.shared.l("watch.connected") : Localizer.shared.l("watch.disconnected"),
                               color: store.isConnected ? wIncome : .secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(wAccent)
                                .frame(width: 20)
                            Text(Localizer.shared.l("settings.language"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        Picker("", selection: Binding(
                            get: { store.currentLanguage },
                            set: { store.updateLanguage($0) }
                        )) {
                            Text("English").tag("en")
                            Text("Türkçe").tag("tr")
                        }
                        .labelsHidden()
                        .frame(height: 32)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    settingRow(icon: "info.circle", 
                               label: Localizer.shared.l("settings.version"), 
                               value: "1.2.0",
                               color: .secondary)

                    Divider().opacity(0.3)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(wAccent)
                                .frame(width: 20)
                            Text("App Lock")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Toggle("", isOn: $securityManager.isLockEnabled)
                                .labelsHidden()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 12)

                Text("ZFlow for Watch")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle(Localizer.shared.l("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
