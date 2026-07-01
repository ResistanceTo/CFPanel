import Foundation
import Observation

@MainActor
@Observable
final class SiteOverviewViewModel {
    @ObservationIgnored
    private let context: ZoneSettingsContext

    init(context: ZoneSettingsContext) {
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var selectedZone: CloudflareZone? { context.selectedZone }
    var tokenVerification: TokenVerification? { context.tokenVerification }
    var lastRefreshAt: Date? { context.lastRefreshAt }
    var zoneDetails: CloudflareZoneDetails? { context.zoneDetails }
    var isRefreshingZoneControls: Bool { context.isRefreshingZoneControls }

    func isLoaded(for zoneID: String) -> Bool {
        context.isLoaded(.zoneOverview, for: zoneID)
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func refreshZoneOverview(force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else {
            context.zoneDetails = nil
            return
        }

        guard force || isLoaded(for: requestContext.zoneID) == false else { return }
        let details = try await context.api.fetchZoneDetails(zoneID: requestContext.zoneID)

        guard context.isCurrent(requestContext) else {
            context.logDebug("Discarded stale zone overview response.")
            return
        }

        context.zoneDetails = details
        context.markLoaded(.zoneOverview, zoneID: requestContext.zoneID)
    }

    func toggleZonePause(_ paused: Bool) async {
        guard let zoneID = selectedZoneID else { return }

        do {
            let details = try await context.withZoneControlsRefresh {
                try await context.api.updateZonePaused(zoneID: zoneID, paused: paused)
            }
            context.zoneDetails = details
            context.presentNotice(paused ? "Zone paused." : "Zone resumed.")
        } catch {
            context.presentError(error)
        }
    }
}
