import Observation

import Foundation
import LocalAuthentication

@Observable
final class BiometricLockService {
    var isLocked = true
    var biometricType: LABiometryType = .none
    
    init() { checkBiometrics() }
    
    func checkBiometrics() {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        biometricType = ctx.biometryType
    }
    
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
    
    func authenticate() async {
        let ctx = LAContext()
        ctx.localizedReason = "Unlock Voice Journal"
        let result = try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your journal")
        isLocked = !(result ?? false)
    }
    
    func lock() { isLocked = true }
}
