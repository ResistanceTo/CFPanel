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
                resource: "Security level",
                from: String(localized: previousLevel.title),
                to: String(localized: resolved.title)
            ))
        } catch {
            context.presentError(error)
        }
    }

    func updateSecurityLevel(_ level: SecurityLevel) async {
        guard let zoneID = selectedZoneID, level != .underAttack else { return }
        let previousLevel = currentSecurityLevel

        do {
            let resolved = try await context.withZoneControlsRefresh {
                try await context.api.updateSecurityLevel(zoneID: zoneID, level: level)
            }
            context.currentSecurityLevel = resolved
            context.lastNonAttackSecurityLevel = resolved
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: "Security level",
                from: String(localized: previousLevel.title),
                to: String(localized: resolved.title)
            ))
        } catch {
            context.presentError(error)
        }
    }

    private func emitUnderAttackFeedback(enabled: Bool) {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(enabled ? .warning : .success)
#endif
    }
}
