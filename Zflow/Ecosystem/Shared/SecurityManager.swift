import Foundation
import LocalAuthentication
import SwiftUI
import Combine

/// Shared manager for biometric and passcode security across iPhone and Watch.
/// Renamed to ZFlowSecurityManager to avoid name clashes with system libraries.
public final class ZFlowSecurityManager: ObservableObject {
    public static let shared = ZFlowSecurityManager()
    
    @AppStorage("zflow.security.isLockedEnabled", store: AppGroup.defaults) 
    public var isLockEnabled: Bool = false
    
    @Published public var isAuthenticated: Bool = false
    
    private let context = LAContext()
    
    private init() {
        // Initial state
        self.isAuthenticated = !isLockEnabled
    }
    
    /// Checks if biometrics (FaceID/TouchID) are available on the device.
    public var canEvaluateBiometrics: Bool {
        #if os(watchOS)
        return false // watchOS handles authentication via the device passcode or companion iPhone unlock
        #else
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #endif
    }
    
    /// Requests biometric or passcode authentication.
    public func authenticate(completion: @escaping (Bool) -> Void) {
        guard isLockEnabled else {
            self.isAuthenticated = true
            completion(true)
            return
        }
        
        let reason = "Authenticate to unlock ZFlow"
        
        // We use .deviceOwnerAuthentication to allow fallback to device passcode
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isAuthenticated = success
                completion(success)
            }
        }
    }
    
    /// Manually locks the app (e.g., when moving to background).
    public func lock() {
        guard isLockEnabled else { return }
        isAuthenticated = false
    }
}
