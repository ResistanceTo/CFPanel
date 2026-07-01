import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

enum DangerousOperationsSettings {
    // Keep this local to the device. Syncing the switch would expose delete UI on other trusted devices.
    static let advancedModeStorageKey = "advanced_dangerous_mode_enabled"
}

enum DangerousActionAuthorizer {
    @MainActor
    static func authorize(reason: String) async throws {
#if canImport(LocalAuthentication)
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else {
            throw CloudflareAPIError.api(
                error?.localizedDescription
                    ?? "Device authentication is unavailable. Configure Face ID, Touch ID, or a device passcode before using dangerous operations."
            )
        }

        do {
            _ = try await context.evaluatePolicy(policy, localizedReason: reason)
        } catch {
            throw CloudflareAPIError.api(error.localizedDescription)
        }
#else
        throw CloudflareAPIError.api("Device authentication is unavailable in this build.")
#endif
    }
}
