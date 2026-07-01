import Foundation
import Observation

@MainActor
@Observable
final class SiteDNSSettingsViewModel {
    @ObservationIgnored
    private let context: ZoneSettingsContext

    init(context: ZoneSettingsContext) {
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var zoneDNSSettings: ZoneDNSSettings? { context.zoneDNSSettings }

    func isLoaded(for zoneID: String) -> Bool {
        context.isLoaded(.dnsSettings, for: zoneID)
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func refreshDNSSettings(force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else { return }
        guard force || isLoaded(for: requestContext.zoneID) == false else { return }

        let settings = try await context.api.fetchDNSSettings(zoneID: requestContext.zoneID)

        guard context.isCurrent(requestContext) else {
            context.logDebug("Discarded stale DNS settings response.")
            return
        }

        context.zoneDNSSettings = settings
        context.markLoaded(.dnsSettings, zoneID: requestContext.zoneID)
    }
}
