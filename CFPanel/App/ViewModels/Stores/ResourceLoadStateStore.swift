import Foundation
import Observation

@MainActor
@Observable
final class ResourceLoadStateStore {
    @ObservationIgnored
    private var state = AppLoadState()

    func resetZoneScopedState() {
        state.dashboardKey = nil
        state.zoneResources.removeAll()
        state.rulesPhaseResources.removeAll()
        resetAccountScopedState()
    }

    func resetAccountScopedState() {
        state.accountResources.removeAll()
    }

    func resetRulesState() {
        state.rulesPhaseResources.removeAll()
    }

    func isDashboardLoaded(for zoneID: String, range: DashboardTimeRange) -> Bool {
        state.dashboardKey == dashboardKey(zoneID: zoneID, range: range)
    }

    func markDashboardLoaded(zoneID: String, range: DashboardTimeRange) {
        state.dashboardKey = dashboardKey(zoneID: zoneID, range: range)
    }

    func isZoneResourceLoaded(_ resource: ZoneLoadResourceKind, zoneID: String) -> Bool {
        state.zoneResources.contains(ZoneLoadResource(zoneID: zoneID, resource: resource))
    }

    func markZoneResourceLoaded(_ resource: ZoneLoadResourceKind, zoneID: String) {
        state.zoneResources.insert(ZoneLoadResource(zoneID: zoneID, resource: resource))
    }

    func isAccountResourceLoaded(_ resource: AccountLoadResourceKind, accountID: String) -> Bool {
        state.accountResources.contains(AccountLoadResource(accountID: accountID, resource: resource))
    }

    func markAccountResourceLoaded(_ resource: AccountLoadResourceKind, accountID: String) {
        state.accountResources.insert(AccountLoadResource(accountID: accountID, resource: resource))
    }

    func isRulesPhaseLoaded(_ phase: CloudflareRulesetPhase, for zoneID: String) -> Bool {
        state.rulesPhaseResources.contains(RulesPhaseLoadResource(zoneID: zoneID, phase: phase))
    }

    func markRulesPhaseLoaded(_ phase: CloudflareRulesetPhase, zoneID: String) {
        state.rulesPhaseResources.insert(RulesPhaseLoadResource(zoneID: zoneID, phase: phase))
    }

    private func dashboardKey(zoneID: String, range: DashboardTimeRange) -> String {
        "\(zoneID):\(range.rawValue)"
    }
}
