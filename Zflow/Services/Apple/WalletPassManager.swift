import Foundation
import Combine
import SwiftUI
import PassKit

/// A utility to interact with Apple Wallet PassKit, specifically checking if the pass exists
/// and presenting the PKAddPassesViewController.
@MainActor
final class WalletPassManager: ObservableObject {
    @Published var isPassAdded: Bool = false
    @Published var errorMessage: String?
    @Published var showAlert: Bool = false
    
    // ZFlow's unique pass identifier (needs to match what will be on the Apple developer portal)
    private let passTypeIdentifier = "pass.com.zflow.budget"
    
    init() {
        checkPassStatus()
    }
    
    func checkPassStatus() {
        self.isPassAdded = false 
    }
    
    func generateAndAddPass(netBalance: Double, budgetAlerts: Int, themeColor: String, textColor: String, userId: String?, familyId: String?) {
        guard let url = URL(string: "\(AppConstants.serverURL)/generate_pass") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "netBalance": netBalance,
            "budgetAlerts": budgetAlerts,
            "themeColor": themeColor,
            "textColor": textColor
        ]
        
        if let uid = userId { payload["userId"] = uid }
        if let fid = familyId { payload["familyId"] = fid }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        Task {
            do {
                print("🎫 [WalletPassManager] Fetching pass from backend...")
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("❌ [WalletPassManager] Backend returned: \((response as? HTTPURLResponse)?.statusCode ?? 0) — skipping")
                    return
                }
                
                print("✅ [WalletPassManager] Received data (\(data.count) bytes)")
                
                do {
                    let pass = try PKPass(data: data)
                    await MainActor.run {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            var topController = rootVC
                            while let presented = topController.presentedViewController {
                                topController = presented
                            }
                            if let addController = PKAddPassesViewController(pass: pass) {
                                topController.present(addController, animated: true)
                            } else {
                                print("❌ [WalletPassManager] PKAddPassesViewController unavailable")
                            }
                        }
                    }
                } catch {
                    print("❌ [WalletPassManager] PKPass init failed: \(error.localizedDescription)")
                }
            } catch {
                print("❌ [WalletPassManager] Request failed (server may be offline): \(error.localizedDescription)")
            }
        }
    }
}
