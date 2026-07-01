import Foundation
import Observation

@MainActor
@Observable
final class ZoneSecurityControlsViewModel {
    @ObservationIgnored
    private let context: ZoneSettingsContext

    init(context: ZoneSettingsContext) {
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var zoneControls: ZoneControlSettings { context.zoneControls }
    var unavailableZoneControls: [ZoneControlToggle: String] { context.unavailableZoneControls }
    var isRefreshingZoneControls: Bool { context.isRefreshingZoneControls }

    func isLoaded(for zoneID: String) -> Bool {
        context.isLoaded(.securityControls, for: zoneID)
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func refreshSecurityZoneControls(force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else { return }
        guard force || isLoaded(for: requestContext.zoneID) == false else { return }

        await context.withZoneControlsRefresh {
            async let browserIntegrityCheck = loadZoneControl(.browserIntegrityCheck, zoneID: requestContext.zoneID)
            async let waf = loadZoneControl(.waf, zoneID: requestContext.zoneID)
            async let botFightMode = loadZoneControl(.botFightMode, zoneID: requestContext.zoneID)

            let resolvedBrowserIntegrityCheck = await browserIntegrityCheck
            let resolvedWAF = await waf
            let resolvedBotFightMode = await botFightMode

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale security controls response.")
                return
            }

            var controls = context.zoneControls
            var unavailable = context.unavailableZoneControls

            apply(resolvedBrowserIntegrityCheck, to: &controls, unavailable: &unavailable)
            apply(resolvedWAF, to: &controls, unavailable: &unavailable)
            apply(resolvedBotFightMode, to: &controls, unavailable: &unavailable)

            context.zoneControls = controls
            context.unavailableZoneControls = unavailable
        }
        context.markLoaded(.securityControls, zoneID: requestContext.zoneID)
    }

    func updateZoneControl(_ setting: ZoneControlToggle, enabled: Bool) async {
        guard let zoneID = selectedZoneID else { return }
        guard unavailableZoneControls[setting] == nil else { return }
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

    private func loadZoneControl(
        _ setting: ZoneControlToggle,
        zoneID: String
    ) async -> ZoneControlLoadResult {
        do {
            let value = try await context.api.fetchToggleSetting(zoneID: zoneID, setting: setting)
            return .available(setting, value)
        } catch let error as CloudflareAPIError {
            if let unavailableMessage = unavailableMessage(for: setting, error: error) {
                return .unavailable(setting, unavailableMessage)
            }
            return .failed(error)
        } catch {
            return .failed(error)
        }
    }

    private func apply(
        _ result: ZoneControlLoadResult,
        to controls: inout ZoneControlSettings,
        unavailable: inout [ZoneControlToggle: String]
    ) {
        switch result {
        case .available(let setting, let value):
            unavailable.removeValue(forKey: setting)
            setValue(value, for: setting, controls: &controls)
        case .unavailable(let setting, let message):
            unavailable[setting] = message
            setValue(false, for: setting, controls: &controls)
        case .failed(let error):
            context.presentError(error)
        }
    }

    private func unavailableMessage(
        for setting: ZoneControlToggle,
        error: CloudflareAPIError
    ) -> String? {
        switch error {
        case .httpStatus(400, let message), .api(let message):
            if message.localizedCaseInsensitiveContains("Undefined zone setting") {
                return "\(setting.title) is unavailable for this zone, token, or Cloudflare plan."
            }
            return nil
        default:
            return nil
        }
    }

    private func value(for setting: ZoneControlToggle) -> Bool {
        switch setting {
        case .browserIntegrityCheck:
            context.zoneControls.browserIntegrityCheck
        case .waf:
            context.zoneControls.waf
        case .botFightMode:
            context.zoneControls.botFightMode
        case .alwaysUseHTTPS, .automaticHTTPSRewrites, .developmentMode, .alwaysOnline:
            false
        }
    }

    private func setValue(_ value: Bool, for setting: ZoneControlToggle) {
        var controls = context.zoneControls
        setValue(value, for: setting, controls: &controls)
        context.zoneControls = controls
    }

    private func setValue(
        _ value: Bool,
        for setting: ZoneControlToggle,
        controls: inout ZoneControlSettings
    ) {
        switch setting {
        case .browserIntegrityCheck:
            controls.browserIntegrityCheck = value
        case .waf:
            controls.waf = value
        case .botFightMode:
            controls.botFightMode = value
        case .alwaysUseHTTPS, .automaticHTTPSRewrites, .developmentMode, .alwaysOnline:
            return
        }
    }
}

private enum ZoneControlLoadResult {
    case available(ZoneControlToggle, Bool)
    case unavailable(ZoneControlToggle, String)
    case failed(Error)
}
