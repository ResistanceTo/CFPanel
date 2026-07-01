import Foundation
import Observation

@MainActor
@Observable
final class AuditLogViewModel {
    @ObservationIgnored
    private let context: DashboardWorkspaceContext

    init(context: DashboardWorkspaceContext) {
        self.context = context
    }

    var resolvedAccountID: String? {
        context.resolvedAccountID
    }

    var selectedZoneID: String? {
        context.selectedZoneID
    }

    var selectedZone: CloudflareZone? {
        context.selectedZone
    }

    func loadAuditLogPage(
        range: AuditLogTimeRange,
        scope: AuditLogScope
    ) async throws -> AuditLogPage {
        let accountID = try context.requireAccountID("This token cannot access account-level activity logs.")
        let before = Date()
        let since = range.sinceDate(relativeTo: before)
        let zoneID = scope == .currentZone ? selectedZoneID : nil

        return try await context.api.listAccountAuditLogs(
            accountID: accountID,
            since: since,
            before: before,
            zoneID: zoneID
        )
    }
}
