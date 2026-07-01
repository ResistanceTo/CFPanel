import Foundation
import Observation

@MainActor
@Observable
final class ZoneWorkspaceStore {
    var zones: [CloudflareZone] = []
    var selectedZoneID: String?
    var dashboard = DashboardSnapshot.placeholder
    var currentSecurityLevel: SecurityLevel = .medium
    var lastNonAttackSecurityLevel: SecurityLevel = .medium
    var lastRefreshAt: Date?
    var zoneDetails: CloudflareZoneDetails?
    var zoneDNSSettings: ZoneDNSSettings?
    var zoneControls = ZoneControlSettings.empty
    var unavailableZoneControls: [ZoneControlToggle: String] = [:]
    var zoneAdvancedSettings = ZoneAdvancedSettings.empty
    var unavailableZoneAdvancedSettings: [ZoneAdvancedToggle: String] = [:]
    var edgeTLSSettings = EdgeTLSSettings.empty
    var zoneCacheSettings = ZoneCacheSettings.empty

    var selectedZone: CloudflareZone? {
        guard let selectedZoneID else { return nil }
        return zones.first { $0.id == selectedZoneID }
    }

    var isUnderAttackModeEnabled: Bool {
        currentSecurityLevel == .underAttack
    }

    func resetZoneScopedState() {
        dashboard = .placeholder
        currentSecurityLevel = .medium
        lastNonAttackSecurityLevel = .medium
        zoneDetails = nil
        zoneDNSSettings = nil
        zoneControls = .empty
        unavailableZoneControls = [:]
        zoneAdvancedSettings = .empty
        unavailableZoneAdvancedSettings = [:]
        edgeTLSSettings = .empty
        zoneCacheSettings = .empty
        lastRefreshAt = nil
    }

    func clearWorkspace() {
        zones = []
        selectedZoneID = nil
        resetZoneScopedState()
    }
}
