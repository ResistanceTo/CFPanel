import Foundation
import Observation

@MainActor
@Observable
final class ZoneTrafficControlsViewModel {
    @ObservationIgnored
    private let context: ZoneSettingsContext

    init(context: ZoneSettingsContext) {
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var zoneControls: ZoneControlSettings { context.zoneControls }
    var isRefreshingZoneControls: Bool { context.isRefreshingZoneControls }

    func isLoaded(for zoneID: String) -> Bool {
        context.isLoaded(.trafficControls, for: zoneID)
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func refreshTrafficZoneControls(force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else { return }
        guard force || isLoaded(for: requestContext.zoneID) == false else { return }

        try await context.withZoneControlsRefresh {
            async let alwaysUseHTTPS = context.api.fetchToggleSetting(zoneID: requestContext.zoneID, setting: .alwaysUseHTTPS)
            async let automaticHTTPSRewrites = context.api.fetchToggleSetting(zoneID: requestContext.zoneID, setting: .automaticHTTPSRewrites)
            async let developmentMode = context.api.fetchToggleSetting(zoneID: requestContext.zoneID, setting: .developmentMode)
            async let alwaysOnline = context.api.fetchToggleSetting(zoneID: requestContext.zoneID, setting: .alwaysOnline)

            let resolvedAlwaysUseHTTPS = try await alwaysUseHTTPS
            let resolvedAutomaticHTTPSRewrites = try await automaticHTTPSRewrites
            let resolvedDevelopmentMode = try await developmentMode
            let resolvedAlwaysOnline = try await alwaysOnline

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale traffic controls response.")
                return
            }

            var controls = context.zoneControls
            controls.alwaysUseHTTPS = resolvedAlwaysUseHTTPS
            controls.automaticHTTPSRewrites = resolvedAutomaticHTTPSRewrites
            controls.developmentMode = resolvedDevelopmentMode
            controls.alwaysOnline = resolvedAlwaysOnline
            context.zoneControls = controls
        }
        context.markLoaded(.trafficControls, zoneID: requestContext.zoneID)
    }

    func updateZoneControl(_ setting: ZoneControlToggle, enabled: Bool) async {
        guard let zoneID = selectedZoneID else { return }
        let previousValue = value(for: setting)

        do {
            let value = try await context.withZoneControlsRefresh {
                try await context.api.updateToggleSetting(zoneID: zoneID, setting: setting, enabled: enabled)
            }
            setValue(value, for: setting)
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: setting.title,
                from: previousValue,
                to: value
            ))
        } catch {
            context.presentError(error)
        }
    }

    private func value(for setting: ZoneControlToggle) -> Bool {
        switch setting {
        case .alwaysUseHTTPS:
            context.zoneControls.alwaysUseHTTPS
        case .automaticHTTPSRewrites:
            context.zoneControls.automaticHTTPSRewrites
        case .developmentMode:
            context.zoneControls.developmentMode
        case .alwaysOnline:
            context.zoneControls.alwaysOnline
        case .browserIntegrityCheck, .waf, .botFightMode:
            false
        }
    }

    private func setValue(_ value: Bool, for setting: ZoneControlToggle) {
        var controls = context.zoneControls
        switch setting {
        case .alwaysUseHTTPS:
            controls.alwaysUseHTTPS = value
        case .automaticHTTPSRewrites:
            controls.automaticHTTPSRewrites = value
        case .developmentMode:
            controls.developmentMode = value
        case .alwaysOnline:
            controls.alwaysOnline = value
        case .browserIntegrityCheck, .waf, .botFightMode:
            return
        }
        context.zoneControls = controls
    }
}
