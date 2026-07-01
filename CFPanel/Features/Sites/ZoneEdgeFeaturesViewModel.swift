import Foundation
import Observation

@MainActor
@Observable
final class ZoneEdgeFeaturesViewModel {
    @ObservationIgnored
    private let context: ZoneSettingsContext

    init(context: ZoneSettingsContext) {
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var zoneAdvancedSettings: ZoneAdvancedSettings { context.zoneAdvancedSettings }
    var unavailableZoneAdvancedSettings: [ZoneAdvancedToggle: String] { context.unavailableZoneAdvancedSettings }
    var isRefreshingZoneControls: Bool { context.isRefreshingZoneControls }

    func isLoaded(for zoneID: String) -> Bool {
        context.isLoaded(.edgeFeatures, for: zoneID)
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func refreshZoneAdvancedSettings(force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else {
            context.zoneAdvancedSettings = .empty
            return
        }

        guard force || isLoaded(for: requestContext.zoneID) == false else { return }

        await context.withZoneControlsRefresh {
            async let http3 = loadAdvancedSetting(.http3, zoneID: requestContext.zoneID)
            async let tls13 = loadAdvancedSetting(.tls13, zoneID: requestContext.zoneID)
            async let webSockets = loadAdvancedSetting(.webSockets, zoneID: requestContext.zoneID)
            async let zeroRTT = loadAdvancedSetting(.zeroRTT, zoneID: requestContext.zoneID)
            async let ipGeolocation = loadAdvancedSetting(.ipGeolocation, zoneID: requestContext.zoneID)
            async let webP = loadAdvancedSetting(.webP, zoneID: requestContext.zoneID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale advanced settings response.")
                return
            }

            var settings = context.zoneAdvancedSettings
            var unavailable = context.unavailableZoneAdvancedSettings

            apply(await http3, to: &settings, unavailable: &unavailable)
            apply(await tls13, to: &settings, unavailable: &unavailable)
            apply(await webSockets, to: &settings, unavailable: &unavailable)
            apply(await zeroRTT, to: &settings, unavailable: &unavailable)
            apply(await ipGeolocation, to: &settings, unavailable: &unavailable)
            apply(await webP, to: &settings, unavailable: &unavailable)

            context.zoneAdvancedSettings = settings
            context.unavailableZoneAdvancedSettings = unavailable
        }
        context.markLoaded(.edgeFeatures, zoneID: requestContext.zoneID)
    }

    func updateAdvancedZoneSetting(_ setting: ZoneAdvancedToggle, enabled: Bool) async {
        guard let zoneID = selectedZoneID else { return }
        guard unavailableZoneAdvancedSettings[setting] == nil else { return }
        let previousValue = value(for: setting)

        do {
            let value = try await context.withZoneControlsRefresh {
                try await context.api.updateBooleanSetting(
                    zoneID: zoneID,
                    settingID: setting.rawValue,
                    enabled: enabled
                )
            }

            var settings = context.zoneAdvancedSettings
            switch setting {
            case .http3:
                settings.http3 = value
            case .tls13:
                settings.tls13 = value
            case .webSockets:
                settings.webSockets = value
            case .zeroRTT:
                settings.zeroRTT = value
            case .ipGeolocation:
                settings.ipGeolocation = value
            case .webP:
                settings.webP = value
            }
            context.zoneAdvancedSettings = settings

            context.markLoaded(.edgeFeatures, zoneID: zoneID)
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: setting.title,
                from: previousValue,
                to: value
            ))
        } catch {
            context.presentError(error)
        }
    }

    private func loadAdvancedSetting(
        _ setting: ZoneAdvancedToggle,
        zoneID: String
    ) async -> ZoneAdvancedSettingLoadResult {
        do {
            let value = try await context.api.fetchBooleanSetting(zoneID: zoneID, settingID: setting.rawValue)
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
        _ result: ZoneAdvancedSettingLoadResult,
        to settings: inout ZoneAdvancedSettings,
        unavailable: inout [ZoneAdvancedToggle: String]
    ) {
        switch result {
        case .available(let setting, let value):
            unavailable.removeValue(forKey: setting)
            setValue(value, for: setting, settings: &settings)
        case .unavailable(let setting, let message):
            unavailable[setting] = message
            setValue(false, for: setting, settings: &settings)
        case .failed(let error):
            if (error as? URLError)?.code == .cancelled {
                return
            }
            context.presentError(error)
        }
    }

    private func unavailableMessage(
        for setting: ZoneAdvancedToggle,
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

    private func value(for setting: ZoneAdvancedToggle) -> Bool {
        switch setting {
        case .http3:
            context.zoneAdvancedSettings.http3
        case .tls13:
            context.zoneAdvancedSettings.tls13
        case .webSockets:
            context.zoneAdvancedSettings.webSockets
        case .zeroRTT:
            context.zoneAdvancedSettings.zeroRTT
        case .ipGeolocation:
            context.zoneAdvancedSettings.ipGeolocation
        case .webP:
            context.zoneAdvancedSettings.webP
        }
    }

    private func setValue(
        _ value: Bool,
        for setting: ZoneAdvancedToggle,
        settings: inout ZoneAdvancedSettings
    ) {
        switch setting {
        case .http3:
            settings.http3 = value
        case .tls13:
            settings.tls13 = value
        case .webSockets:
            settings.webSockets = value
        case .zeroRTT:
            settings.zeroRTT = value
        case .ipGeolocation:
            settings.ipGeolocation = value
        case .webP:
            settings.webP = value
        }
    }
}

private enum ZoneAdvancedSettingLoadResult {
    case available(ZoneAdvancedToggle, Bool)
    case unavailable(ZoneAdvancedToggle, String)
    case failed(Error)
}
