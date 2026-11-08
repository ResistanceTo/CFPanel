import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class SecurityLevelViewModel {
    @ObservationIgnored
    private let context: SecurityWorkspaceContext

    init(context: SecurityWorkspaceContext) {
        self.context = context
    }

    var selectedZoneID: String? {
        context.selectedZoneID
    }

    var selectedZone: CloudflareZone? {
        context.selectedZone
    }

    var tokenVerification: TokenVerification? {
        context.tokenVerification
    }

    var lastRefreshAt: Date? {
        context.lastRefreshAt
    }

    var currentSecurityLevel: SecurityLevel {
        context.currentSecurityLevel
    }

    var lastNonAttackSecurityLevel: SecurityLevel {
        context.lastNonAttackSecurityLevel
    }

    var isUnderAttackModeEnabled: Bool {
        context.isUnderAttackModeEnabled
    }

    var isPerformingPanicAction: Bool {
        context.isPerformingPanicAction
    }

    var isRefreshingZoneControls: Bool {
        context.isRefreshingZoneControls
    }

    func isSecurityLoaded(for zoneID: String) -> Bool {
        context.isSecurityLoaded(for: zoneID)
    }

    func refreshSecurityState() async throws {
        guard let requestContext = context.makeZoneRequestContext() else { return }
        let value = try await context.api.fetchSecurityLevel(zoneID: requestContext.zoneID)

        guard context.isCurrent(requestContext) else {
            context.logDebug("Discarded stale security state response.")
            return
        }

        let resolved = SecurityLevel(rawValue: value) ?? .medium
        if resolved != .underAttack {
            context.lastNonAttackSecurityLevel = resolved
        }
        context.currentSecurityLevel = resolved
        context.markSecurityLoaded(zoneID: requestContext.zoneID)
    }

    func setUnderAttackMode(_ enabled: Bool) async {
        guard let zoneID = selectedZoneID else { return }
        let previousLevel = currentSecurityLevel

        do {
            let targetLevel: SecurityLevel = enabled ? .underAttack : lastNonAttackSecurityLevel
            let resolved = try await context.withPanicAction {
                try await context.api.updateSecurityLevel(zoneID: zoneID, level: targetLevel)
            }
            if enabled {
                context.lastNonAttackSecurityLevel = currentSecurityLevel
            }
            context.currentSecurityLevel = resolved
            emitUnderAttackFeedback(enabled: isUnderAttackModeEnabled)
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: "Under Attack Mode",
                from: underAttackStateTitle(previousLevel),
                to: underAttackStateTitle(resolved)
            ))
        } catch {
            context.presentError(error)
        }
    }

    // Since 2026-04-16 Cloudflare's security level only switches Under Attack Mode on or off;
    // Low/Medium/High no longer change behavior, so the app only exposes the on/off state.
    private func underAttackStateTitle(_ level: SecurityLevel) -> String {
        level == .underAttack ? String(localized: "Enabled") : String(localized: "Disabled")
    }

    private func emitUnderAttackFeedback(enabled: Bool) {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(enabled ? .warning : .success)
#endif
    }
}
