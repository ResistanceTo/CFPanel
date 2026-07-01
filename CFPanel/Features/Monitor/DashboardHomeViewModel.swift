import Foundation
import Observation

@MainActor
@Observable
final class DashboardHomeViewModel {
    @ObservationIgnored
    private let context: DashboardWorkspaceContext

    init(context: DashboardWorkspaceContext) {
        self.context = context
    }

    var zones: [CloudflareZone] {
        context.zones
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

    var zoneDetails: CloudflareZoneDetails? {
        context.zoneDetails
    }

    var dashboard: DashboardSnapshot {
        context.dashboard
    }

    var isRefreshingDashboard: Bool {
        context.isRefreshingDashboard
    }

    func openSitesTab() {
        context.openSitesTab()
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func isDashboardLoaded(for zoneID: String, range: DashboardTimeRange) -> Bool {
        context.isDashboardLoaded(for: zoneID, range: range)
    }

    func refreshHome(range: DashboardTimeRange = .last24Hours, force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else {
            context.dashboard = .placeholder
            context.zoneDetails = nil
            return
        }

        guard force || isDashboardLoaded(for: requestContext.zoneID, range: range) == false else { return }

        try await context.withDashboardRefresh {
            async let details = context.api.fetchZoneDetails(zoneID: requestContext.zoneID)
            async let snapshot = context.api.fetchDashboard(zoneID: requestContext.zoneID, range: range)

            let resolvedDetails = try await details
            let resolvedSnapshot = try await snapshot

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale dashboard home response.")
                return
            }

            context.zoneDetails = resolvedDetails
            context.dashboard = resolvedSnapshot
            context.markDashboardLoaded(zoneID: requestContext.zoneID, range: range)
            context.markZoneOverviewLoaded(zoneID: requestContext.zoneID)
        }
    }

    func refresh(range: DashboardTimeRange = .last24Hours) async throws {
        guard let requestContext = context.makeZoneRequestContext() else { return }

        try await context.withDashboardRefresh {
            let resolvedDashboard = try await context.api.fetchDashboard(zoneID: requestContext.zoneID, range: range)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale dashboard response.")
                return
            }

            context.dashboard = resolvedDashboard
            context.markDashboardLoaded(zoneID: requestContext.zoneID, range: range)
        }
    }
}
