import Foundation
import Observation

@MainActor
@Observable
final class CachePurgeViewModel {
    private static let maxCustomURLPurgeCount = 30

    @ObservationIgnored
    private let context: SecurityWorkspaceContext

    init(context: SecurityWorkspaceContext) {
        self.context = context
    }

    var selectedZoneID: String? {
        context.selectedZoneID
    }

    var selectedZone: CloudflareZone? {
        context.selectedZone
    }

    var isPerformingPanicAction: Bool {
        context.isPerformingPanicAction
    }

    func purgeEverything() async {
        guard let zoneID = selectedZoneID else { return }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm purging all cached assets for \(selectedZone?.name ?? "the active site")."
            )
            try await context.withPanicAction {
                try await context.api.purgeEverything(zoneID: zoneID)
            }
            context.presentNotice("Cache purge submitted.")
        } catch {
            context.presentError(error)
        }
    }

    func purgeCustomURLs(_ rawValue: String) async {
        guard let zoneID = selectedZoneID else { return }

        let urls = rawValue
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard urls.isEmpty == false else {
            context.presentAPIError("Add at least one URL to purge.")
            return
        }

        guard urls.count <= Self.maxCustomURLPurgeCount else {
            context.presentAPIError("Purge at most 30 URLs at a time to stay within Cloudflare's custom purge request limit.")
            return
        }

        let invalidURLs = urls.filter { isValidPurgeURL($0) == false }
        guard invalidURLs.isEmpty else {
            context.presentAPIError(
                "Only valid http:// or https:// URLs can be purged. Check: \(invalidURLs.prefix(2).joined(separator: ", "))"
            )
            return
        }

        if let zoneName = selectedZone?.name {
            let outOfZoneURLs = urls.filter { belongsToZone($0, zoneName: zoneName) == false }
            guard outOfZoneURLs.isEmpty else {
                context.presentAPIError(
                    "Only purge URLs for \(zoneName). Check: \(outOfZoneURLs.prefix(2).joined(separator: ", "))"
                )
                return
            }
        }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm purging \(urls.count) cached URLs for \(selectedZone?.name ?? "the active site")."
            )
            try await context.withPanicAction {
                try await context.api.purge(urls: urls, zoneID: zoneID)
            }
            context.presentNotice("Custom purge submitted.")
        } catch {
            context.presentError(error)
        }
    }

    private func isValidPurgeURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              host.isEmpty == false
        else {
            return false
        }

        return true
    }

    private func belongsToZone(_ value: String, zoneName: String) -> Bool {
        guard let host = URLComponents(string: value)?.host?.lowercased() else {
            return false
        }

        let normalizedZoneName = zoneName.lowercased()
        return host == normalizedZoneName || host.hasSuffix(".\(normalizedZoneName)")
    }
}
