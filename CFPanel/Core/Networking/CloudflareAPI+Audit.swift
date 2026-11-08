import Foundation

extension CloudflareAPI {
    /// Lists account audit log entries without `view` actions. Since 2026-10-13 Audit Logs v2
    /// records every GET as a `view`, so CFPanel's own reads would otherwise bury real changes.
    func listAccountAuditLogs(
        accountID: String,
        since: Date,
        before: Date,
        zoneID: String?,
        limit: Int = 100
    ) async throws -> AuditLogPage {
        let page: AuditLogPage
        do {
            page = try await fetchAccountAuditLogPage(
                accountID: accountID, since: since, before: before, zoneID: zoneID, limit: limit,
                excludeViewActions: true
            )
        } catch let CloudflareAPIError.httpStatus(code, _) where code == 400 || code == 422 {
            // The query-string form of the `action_type` "not" filter isn't documented. If
            // Cloudflare rejects it, fetch without it and rely on the local filter below.
            page = try await fetchAccountAuditLogPage(
                accountID: accountID, since: since, before: before, zoneID: zoneID, limit: limit,
                excludeViewActions: false
            )
        }

        return AuditLogPage(
            entries: page.entries.filter { $0.action?.type?.lowercased() != "view" },
            resultInfo: page.resultInfo
        )
    }

    private func fetchAccountAuditLogPage(
        accountID: String,
        since: Date,
        before: Date,
        zoneID: String?,
        limit: Int,
        excludeViewActions: Bool
    ) async throws -> AuditLogPage {
        var components = URLComponents()
        components.path = "/accounts/\(accountID)/logs/audit"
        components.queryItems = [
            URLQueryItem(name: "since", value: iso8601String(from: since)),
            URLQueryItem(name: "before", value: iso8601String(from: before)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let zoneID, zoneID.isEmpty == false {
            components.queryItems?.append(URLQueryItem(name: "zone_id", value: zoneID))
        }

        if excludeViewActions {
            components.queryItems?.append(URLQueryItem(name: "action_type.not", value: "view"))
        }

        let requestPath = components.path + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
        let envelope: CloudflareEnvelope<[AuditLogEntry]> = try await requestEnvelope(path: requestPath)

        guard envelope.success else {
            let message = envelope.errors?.first?.message
                ?? envelope.messages?.first?.message
                ?? "Cloudflare returned an empty audit log response."
            throw CloudflareAPIError.api(message)
        }

        return AuditLogPage(
            entries: envelope.result ?? [],
            resultInfo: envelope.resultInfo
        )
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
