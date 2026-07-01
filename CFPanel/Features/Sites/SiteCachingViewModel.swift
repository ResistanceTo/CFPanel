import Foundation
import Observation

@MainActor
@Observable
final class SiteCachingViewModel {
    @ObservationIgnored
    private let context: ZoneSettingsContext

    init(context: ZoneSettingsContext) {
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var zoneControls: ZoneControlSettings { context.zoneControls }
    var zoneCacheSettings: ZoneCacheSettings { context.zoneCacheSettings }
    var isRefreshingZoneControls: Bool { context.isRefreshingZoneControls }

    func isLoaded(for zoneID: String) -> Bool {
        context.isLoaded(.caching, for: zoneID)
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func refreshCachingPageData(force: Bool = false) async throws {
        guard let requestContext = context.makeZoneRequestContext() else {
            var controls = context.zoneControls
            controls.developmentMode = false
            controls.alwaysOnline = false
            context.zoneControls = controls
            return
        }

        guard force || isLoaded(for: requestContext.zoneID) == false else { return }

        try await context.withZoneControlsRefresh {
            async let developmentMode = context.api.fetchToggleSetting(zoneID: requestContext.zoneID, setting: .developmentMode)
            async let alwaysOnline = context.api.fetchToggleSetting(zoneID: requestContext.zoneID, setting: .alwaysOnline)
            async let cacheLevel = context.api.fetchCacheLevel(zoneID: requestContext.zoneID)
            async let browserCacheTTL = context.api.fetchBrowserCacheTTL(zoneID: requestContext.zoneID)

            let resolvedDevelopmentMode = try await developmentMode
            let resolvedAlwaysOnline = try await alwaysOnline

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale caching response.")
                return
            }

            var controls = context.zoneControls
            controls.developmentMode = resolvedDevelopmentMode
            controls.alwaysOnline = resolvedAlwaysOnline
            context.zoneControls = controls
            context.zoneCacheSettings = ZoneCacheSettings(
                cacheLevel: (try? await cacheLevel) ?? .aggressive,
                browserCacheTTL: (try? await browserCacheTTL) ?? 14400
            )
        }
        context.markLoaded(.caching, zoneID: requestContext.zoneID)
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
            case .developmentMode:
                controls.developmentMode = value
            case .alwaysOnline:
                controls.alwaysOnline = value
            case .alwaysUseHTTPS, .automaticHTTPSRewrites, .browserIntegrityCheck, .waf, .botFightMode:
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

    func updateCacheLevel(_ level: CacheLevel) async {
        guard let zoneID = selectedZoneID else { return }
        let previousLevel = context.zoneCacheSettings.cacheLevel

        do {
            let resolved = try await context.withZoneControlsRefresh {
                try await context.api.updateCacheLevel(zoneID: zoneID, level: level)
            }
            var settings = context.zoneCacheSettings
            settings.cacheLevel = resolved
            context.zoneCacheSettings = settings
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: "Cache level",
                from: previousLevel.title,
                to: resolved.title
            ))
        } catch {
            context.presentError(error)
        }
    }

    func updateBrowserCacheTTL(_ ttl: Int) async {
        guard let zoneID = selectedZoneID else { return }
        let previousTTL = context.zoneCacheSettings.browserCacheTTL

        do {
            let resolved = try await context.withZoneControlsRefresh {
                try await context.api.updateBrowserCacheTTL(zoneID: zoneID, ttl: ttl)
            }
            var settings = context.zoneCacheSettings
            settings.browserCacheTTL = resolved
            context.zoneCacheSettings = settings
            context.presentNotice(DangerousOperationMessage.changeNotice(
                resource: "Browser cache TTL",
                from: ZoneCacheSettings.formatTTL(previousTTL),
                to: ZoneCacheSettings.formatTTL(resolved)
            ))
        } catch {
            context.presentError(error)
        }
    }

    private func value(for setting: ZoneControlToggle) -> Bool {
        switch setting {
        case .developmentMode:
            context.zoneControls.developmentMode
        case .alwaysOnline:
            context.zoneControls.alwaysOnline
        case .alwaysUseHTTPS, .automaticHTTPSRewrites, .browserIntegrityCheck, .waf, .botFightMode:
            false
        }
    }
}
