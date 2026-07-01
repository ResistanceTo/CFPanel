import Foundation
import Observation

@MainActor
@Observable
final class SiteTLSViewModel {
    @ObservationIgnored
    private let context: ZoneSettingsContext

    init(context: ZoneSettingsContext) {
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var zoneControls: ZoneControlSettings { context.zoneControls }
    var edgeTLSSettings: EdgeTLSSettings { context.edgeTLSSettings }
    var isRefreshingZoneControls: Bool { context.isRefreshingZoneControls }

    func isTLSLoaded(for zoneID: String) -> Bool {
        context.isLoaded(.tls, for: zoneID)
    }

    func isHSTSLoaded(for zoneID: String) -> Bool {
        context.isLoaded(.hsts, for: zoneID)
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func refreshTLSPageData(force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else {
            context.edgeTLSSettings = .empty
            var controls = context.zoneControls
            controls.alwaysUseHTTPS = false
            controls.automaticHTTPSRewrites = false
            context.zoneControls = controls
            return
        }

        guard force || isTLSLoaded(for: requestContext.zoneID) == false else { return }

        try await context.withZoneControlsRefresh {
            async let sslModeValue = context.api.fetchStringSetting(zoneID: requestContext.zoneID, setting: "ssl")
            async let minTLSValue = context.api.fetchStringSetting(zoneID: requestContext.zoneID, setting: "min_tls_version")
            async let alwaysUseHTTPS = context.api.fetchToggleSetting(zoneID: requestContext.zoneID, setting: .alwaysUseHTTPS)
            async let automaticHTTPSRewrites = context.api.fetchToggleSetting(zoneID: requestContext.zoneID, setting: .automaticHTTPSRewrites)

            let sslMode = try await sslModeValue
            let minTLS = try await minTLSValue

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale TLS page response.")
                return
            }

            context.edgeTLSSettings = EdgeTLSSettings(
                sslMode: CloudflareSSLMode(rawValue: sslMode) ?? .full,
                minimumTLSVersion: MinimumTLSVersion(rawValue: minTLS) ?? .v12
            )
            var controls = context.zoneControls
            controls.alwaysUseHTTPS = try await alwaysUseHTTPS
            controls.automaticHTTPSRewrites = try await automaticHTTPSRewrites
            context.zoneControls = controls
        }
        context.markLoaded(.tls, zoneID: requestContext.zoneID)
    }

    func refreshHSTSSettings(force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else {
            var settings = context.edgeTLSSettings
            settings.hsts = .disabled
            context.edgeTLSSettings = settings
            return
        }

        guard force || isHSTSLoaded(for: requestContext.zoneID) == false else { return }

        let hsts = try await context.api.fetchHSTSSettings(zoneID: requestContext.zoneID)

        guard context.isCurrent(requestContext) else {
            context.logDebug("Discarded stale HSTS response.")
            return
        }

        var settings = context.edgeTLSSettings
        settings.hsts = hsts
        context.edgeTLSSettings = settings
        context.markLoaded(.hsts, zoneID: requestContext.zoneID)
    }

    func updateZoneControl(_ setting: ZoneControlToggle, enabled: Bool) async {
        guard let zoneID = selectedZoneID else { return }
        let previousValue = value(for: setting)

        do {
            let value = try await context.withZoneControlsRefresh {
                try await context.api.updateToggleSetting(zoneID: zoneID, setting: setting, enabled: enabled)
            }
            var controls = context.zoneControls
            switch setting {
            case .alwaysUseHTTPS:
                controls.alwaysUseHTTPS = value
            case .automaticHTTPSRewrites:
                controls.automaticHTTPSRewrites = value
            case .developmentMode, .browserIntegrityCheck, .alwaysOnline, .waf, .botFightMode:
                return
            }
            context.zoneControls = controls
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: setting.title,
                from: previousValue,
                to: value
            ))
        } catch {
            context.presentError(error)
        }
    }

    func updateSSLMode(_ mode: CloudflareSSLMode) async {
        guard let zoneID = selectedZoneID else { return }
        let previousMode = context.edgeTLSSettings.sslMode

        do {
            let value = try await context.withZoneControlsRefresh {
                try await context.api.updateStringSetting(zoneID: zoneID, setting: "ssl", value: mode.rawValue)
            }
            let resolvedMode = CloudflareSSLMode(rawValue: value) ?? mode
            if let resolvedMode = CloudflareSSLMode(rawValue: value) {
                var settings = context.edgeTLSSettings
                settings.sslMode = resolvedMode
                context.edgeTLSSettings = settings
            }
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: "SSL mode",
                from: String(localized: previousMode.title),
                to: String(localized: resolvedMode.title)
            ))
        } catch {
            context.presentError(error)
        }
    }

    func updateMinimumTLSVersion(_ version: MinimumTLSVersion) async {
        guard let zoneID = selectedZoneID else { return }
        let previousVersion = context.edgeTLSSettings.minimumTLSVersion

        do {
            let value = try await context.withZoneControlsRefresh {
                try await context.api.updateStringSetting(
                    zoneID: zoneID,
                    setting: "min_tls_version",
                    value: version.rawValue
                )
            }
            let resolvedVersion = MinimumTLSVersion(rawValue: value) ?? version
            if let resolvedVersion = MinimumTLSVersion(rawValue: value) {
                var settings = context.edgeTLSSettings
                settings.minimumTLSVersion = resolvedVersion
                context.edgeTLSSettings = settings
            }
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: "Minimum TLS version",
                from: previousVersion.title,
                to: resolvedVersion.title
            ))
        } catch {
            context.presentError(error)
        }
    }

    func updateHSTSSettings(_ settings: HSTSSettings) async {
        guard let zoneID = selectedZoneID else { return }
        let previousSettings = context.edgeTLSSettings.hsts

        do {
            let resolved = try await context.withZoneControlsRefresh {
                try await context.api.updateHSTSSettings(zoneID: zoneID, settings: settings)
            }
            var tlsSettings = context.edgeTLSSettings
            tlsSettings.hsts = resolved
            context.edgeTLSSettings = tlsSettings
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: "HSTS",
                from: hstsSummary(previousSettings),
                to: hstsSummary(resolved)
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
        case .developmentMode, .browserIntegrityCheck, .alwaysOnline, .waf, .botFightMode:
            false
        }
    }

    private func hstsSummary(_ settings: HSTSSettings) -> String {
        settings.enabled ? "Enabled, max-age \(settings.maxAge)" : "Disabled"
    }
}
