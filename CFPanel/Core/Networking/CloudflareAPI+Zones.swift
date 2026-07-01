import Foundation

extension CloudflareAPI {
    func verifyToken(mode: AuthTokenMode = .account, accountID: String? = nil) async throws -> TokenVerification {
        let resolvedAccountID = accountID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard resolvedAccountID.isEmpty == false else {
            throw CloudflareAPIError.api("Account ID is required for account API tokens.")
        }
        return try await request(path: "/accounts/\(resolvedAccountID)/tokens/verify")
    }

    func listZones() async throws -> [CloudflareZone] {
        try await requestAllPages(path: "/zones", perPage: 50)
    }

    func fetchDashboard(zoneID: String, range: DashboardTimeRange = .last24Hours) async throws -> DashboardSnapshot {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let start: Date
        switch range {
        case .last24Hours:
            start = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
        case .last7Days:
            start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        }

        let query: String
        let variables: JSONValue
        if range.usesHourlyBuckets {
            query = """
            query Dashboard($zoneTag: string, $since: string, $until: string) {
              viewer {
                zones(filter: { zoneTag: $zoneTag }) {
                  totals: httpRequests1hGroups(
                    limit: 10000,
                    filter: { datetime_geq: $since, datetime_lt: $until }
                  ) {
                    uniq {
                      uniques
                    }
                    sum {
                      requests
                      bytes
                      cachedBytes
                      cachedRequests
                      threats
                      pageViews
                      responseStatusMap {
                        edgeResponseStatus
                        requests
                      }
                      countryMap {
                        clientCountryName
                        requests
                        bytes
                        threats
                      }
                      contentTypeMap {
                        edgeResponseContentTypeName
                        requests
                        bytes
                      }
                    }
                  }
                  series: httpRequests1hGroups(
                    orderBy: [datetime_ASC],
                    limit: 10000,
                    filter: { datetime_geq: $since, datetime_lt: $until }
                  ) {
                    sum {
                      requests
                      bytes
                    }
                    dimensions {
                      timeslot: datetime
                    }
                  }
                }
              }
            }
            """
            variables = .object([
                "zoneTag": .string(zoneID),
                "since": .string(Self.graphQLDateFormatter.string(from: start)),
                "until": .string(Self.graphQLDateFormatter.string(from: now))
            ])
        } else {
            query = """
            query Dashboard($zoneTag: string, $since: string, $until: string) {
              viewer {
                zones(filter: { zoneTag: $zoneTag }) {
                  totals: httpRequests1dGroups(
                    limit: 10000,
                    filter: { date_geq: $since, date_lt: $until }
                  ) {
                    uniq {
                      uniques
                    }
                    sum {
                      requests
                      bytes
                      cachedBytes
                      cachedRequests
                      threats
                      pageViews
                      responseStatusMap {
                        edgeResponseStatus
                        requests
                      }
                      countryMap {
                        clientCountryName
                        requests
                        bytes
                        threats
                      }
                      contentTypeMap {
                        edgeResponseContentTypeName
                        requests
                        bytes
                      }
                    }
                  }
                  series: httpRequests1dGroups(
                    orderBy: [date_ASC],
                    limit: 10000,
                    filter: { date_geq: $since, date_lt: $until }
                  ) {
                    sum {
                      requests
                      bytes
                    }
                    dimensions {
                      timeslot: date
                    }
                  }
                }
              }
            }
            """
            variables = .object([
                "zoneTag": .string(zoneID),
                "since": .string(Self.graphQLDayFormatter.string(from: start)),
                "until": .string(Self.graphQLDayFormatter.string(from: now))
            ])
        }

        let dashboardBody = GraphQLRequest(
            query: query,
            variables: variables
        )

        let response: GraphQLResponse<CombinedDashboardGraphQLData> = try await graphQL(dashboardBody)
        guard let zone = response.data?.viewer.zones.first else {
            return .placeholder
        }

        let groups = zone.series
        guard groups.isEmpty == false else {
            return .placeholder
        }

        let points = groups
            .compactMap { group -> TrafficPoint? in
                guard
                    let timeslot = group.dimensions.timeslot,
                    let stamp = Self.parseGraphQLTimeslot(timeslot, range: range)
                else {
                    return nil
                }

                return TrafficPoint(
                    timestamp: stamp,
                    requests: group.sum.requests ?? 0,
                    bandwidth: Int64(group.sum.bytes ?? 0)
                )
            }
            .sorted { $0.timestamp < $1.timestamp }

        let insights = makeTrafficInsights(from: zone.totals.first)

        return DashboardSnapshot(
            range: range,
            totalRequests: zone.totals.first?.sum.requests ?? points.reduce(0) { $0 + $1.requests },
            totalBandwidth: zone.totals.first?.sum.bytes.map(Int64.init) ?? points.reduce(0) { $0 + $1.bandwidth },
            timeseries: points,
            insights: insights
        )
    }

    func fetchZoneDetails(zoneID: String) async throws -> CloudflareZoneDetails {
        try await request(path: "/zones/\(zoneID)")
    }

    func fetchDNSSettings(zoneID: String) async throws -> ZoneDNSSettings {
        try await request(path: "/zones/\(zoneID)/dns_settings")
    }

    func fetchToggleSetting(zoneID: String, setting: ZoneControlToggle) async throws -> Bool {
        try await fetchBooleanSetting(zoneID: zoneID, settingID: setting.rawValue)
    }

    func fetchBooleanSetting(zoneID: String, settingID: String) async throws -> Bool {
        let result: ZoneSettingValueResponse = try await request(
            path: "/zones/\(zoneID)/settings/\(settingID)"
        )
        return result.boolValue
    }

    func updateToggleSetting(zoneID: String, setting: ZoneControlToggle, enabled: Bool) async throws -> Bool {
        try await updateBooleanSetting(zoneID: zoneID, settingID: setting.rawValue, enabled: enabled)
    }

    func updateBooleanSetting(zoneID: String, settingID: String, enabled: Bool) async throws -> Bool {
        let result: ZoneSettingValueResponse = try await request(
            path: "/zones/\(zoneID)/settings/\(settingID)",
            method: "PATCH",
            body: ZoneSettingValueUpdate(value: .string(enabled ? "on" : "off"))
        )
        return result.boolValue
    }

    func fetchStringSetting(zoneID: String, setting: String) async throws -> String {
        let result: ZoneSettingValueResponse = try await request(
            path: "/zones/\(zoneID)/settings/\(setting)"
        )
        return result.stringValue
    }

    func updateStringSetting(zoneID: String, setting: String, value: String) async throws -> String {
        let result: ZoneSettingValueResponse = try await request(
            path: "/zones/\(zoneID)/settings/\(setting)",
            method: "PATCH",
            body: ZoneSettingValueUpdate(value: .string(value))
        )
        return result.stringValue
    }

    func updateSecurityLevel(zoneID: String, level: SecurityLevel) async throws -> SecurityLevel {
        let payload = ZoneSettingUpdate(value: level.rawValue)
        let result: ZoneSettingResponse = try await request(
            path: "/zones/\(zoneID)/settings/security_level",
            method: "PATCH",
            body: payload
        )
        return SecurityLevel(rawValue: result.value) ?? level
    }

    func updateZonePaused(zoneID: String, paused: Bool) async throws -> CloudflareZoneDetails {
        try await request(
            path: "/zones/\(zoneID)",
            method: "PATCH",
            body: ZonePausedUpdate(paused: paused)
        )
    }

    func fetchHSTSSettings(zoneID: String) async throws -> HSTSSettings {
        let response: SecurityHeaderResponse = try await request(
            path: "/zones/\(zoneID)/settings/security_header"
        )
        return response.value?.strictTransportSecurity ?? .disabled
    }

    func updateHSTSSettings(zoneID: String, settings: HSTSSettings) async throws -> HSTSSettings {
        let payload = SecurityHeaderUpdatePayload(
            value: SecurityHeaderSettingValue(strictTransportSecurity: settings)
        )
        let response: SecurityHeaderResponse = try await request(
            path: "/zones/\(zoneID)/settings/security_header",
            method: "PATCH",
            body: payload
        )
        return response.value?.strictTransportSecurity ?? settings
    }

    func fetchCacheLevel(zoneID: String) async throws -> CacheLevel {
        let result: ZoneSettingValueResponse = try await request(
            path: "/zones/\(zoneID)/settings/cache_level"
        )
        return CacheLevel(rawValue: result.stringValue) ?? .aggressive
    }

    func updateCacheLevel(zoneID: String, level: CacheLevel) async throws -> CacheLevel {
        let result: ZoneSettingValueResponse = try await request(
            path: "/zones/\(zoneID)/settings/cache_level",
            method: "PATCH",
            body: ZoneSettingValueUpdate(value: .string(level.rawValue))
        )
        return CacheLevel(rawValue: result.stringValue) ?? level
    }

    func fetchBrowserCacheTTL(zoneID: String) async throws -> Int {
        let result: ZoneSettingValueResponse = try await request(
            path: "/zones/\(zoneID)/settings/browser_cache_ttl"
        )
        if case .number(let value) = result.value {
            return Int(value)
        }
        return 14400
    }

    func updateBrowserCacheTTL(zoneID: String, ttl: Int) async throws -> Int {
        let result: ZoneSettingValueResponse = try await request(
            path: "/zones/\(zoneID)/settings/browser_cache_ttl",
            method: "PATCH",
            body: ZoneSettingValueUpdate(value: .number(Double(ttl)))
        )
        if case .number(let value) = result.value {
            return Int(value)
        }
        return ttl
    }

    func fetchSecurityLevel(zoneID: String) async throws -> String {
        let result: ZoneSettingResponse = try await request(
            path: "/zones/\(zoneID)/settings/security_level"
        )
        return result.value
    }

    func purgeEverything(zoneID: String) async throws {
        _ = try await request(
            path: "/zones/\(zoneID)/purge_cache",
            method: "POST",
            body: PurgeEverythingRequest(purgeEverything: true)
        ) as PurgeCacheResponse
    }

    func purge(urls: [String], zoneID: String) async throws {
        _ = try await request(
            path: "/zones/\(zoneID)/purge_cache",
            method: "POST",
            body: PurgeURLRequest(files: urls)
        ) as PurgeCacheResponse
    }

    func graphQL<Response: Decodable>(_ body: GraphQLRequest) async throws -> Response {
        guard let token, token.isEmpty == false else {
            throw CloudflareAPIError.missingToken
        }

        var request = URLRequest(url: try endpointURL(path: "graphql"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let data = try await performData(for: request)
        if let errors = try? decoder.decode(GraphQLErrorEnvelope.self, from: data),
           let firstError = errors.errors?.first
        {
            throw CloudflareAPIError.graphQL(firstError.message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw CloudflareAPIError.decoding(
                "Failed to decode GraphQL response. Enable CFPANEL_LOG_RESPONSE_BODIES=1 in the debug environment to inspect the payload."
            )
        }
    }

    func fetchTrafficInsights(zoneID: String, start: Date, end: Date) async throws -> TrafficInsightsSnapshot? {
        let body = GraphQLRequest(
            query: """
            query DashboardTrafficInsights($zoneTag: string, $since: string, $until: string) {
              viewer {
                zones(filter: { zoneTag: $zoneTag }) {
                  totals: httpRequests1hGroups(limit: 10000, filter: { datetime_geq: $since, datetime_lt: $until }) {
                    sum {
                      requests
                      bytes
                      cachedBytes
                      cachedRequests
                      threats
                      pageViews
                      responseStatusMap {
                        edgeResponseStatus
                        requests
                      }
                      countryMap {
                        clientCountryName
                        requests
                        bytes
                        threats
                      }
                      contentTypeMap {
                        edgeResponseContentTypeName
                        requests
                        bytes
                      }
                    }
                    uniq {
                      uniques
                    }
                  }
                }
              }
            }
            """,
            variables: .object([
                "zoneTag": .string(zoneID),
                "since": .string(Self.graphQLDateFormatter.string(from: start)),
                "until": .string(Self.graphQLDateFormatter.string(from: end))
            ])
        )

        let response: GraphQLResponse<DashboardTrafficInsightsGraphQLData> = try await graphQL(body)
        return makeTrafficInsights(from: response.data?.viewer.zones.first?.totals.first)
    }

    private func makeTrafficInsights(
        from group: DashboardTrafficInsightsGraphQLData.Group?
    ) -> TrafficInsightsSnapshot? {
        guard
            let group,
            let statusMap = group.sum.responseStatusMap,
            statusMap.isEmpty == false
        else {
            return nil
        }

        let filteredStatuses = statusMap.filter { item in
            item.edgeResponseStatus > 0 && item.requests > 0
        }
        let unsortedBuckets = filteredStatuses.map { item in
            HTTPStatusBucket(code: item.edgeResponseStatus, requests: item.requests)
        }
        let buckets = unsortedBuckets.sorted { lhs, rhs in
            if lhs.requests == rhs.requests {
                return lhs.code < rhs.code
            }
            return lhs.requests > rhs.requests
        }

        guard buckets.isEmpty == false else {
            return nil
        }

        let successfulRequests = buckets
            .filter { (200 ..< 300).contains($0.code) }
            .reduce(0) { $0 + $1.requests }
        let redirectedRequests = buckets
            .filter { (300 ..< 400).contains($0.code) }
            .reduce(0) { $0 + $1.requests }
        let clientErrorRequests = buckets
            .filter { (400 ..< 500).contains($0.code) }
            .reduce(0) { $0 + $1.requests }
        let serverErrorRequests = buckets
            .filter { (500 ..< 600).contains($0.code) }
            .reduce(0) { $0 + $1.requests }

        let health = TrafficHealthSnapshot(
            successfulRequests: successfulRequests,
            redirectedRequests: redirectedRequests,
            clientErrorRequests: clientErrorRequests,
            serverErrorRequests: serverErrorRequests,
            totalBytes: Int64(group.sum.bytes ?? 0),
            statusBreakdown: Array(buckets.prefix(6))
        )

        let countryMap = group.sum.countryMap ?? []
        let mappedCountries = countryMap
            .filter { $0.requests > 0 }
            .map {
                TrafficCountryBucket(
                    countryCode: $0.clientCountryName,
                    requests: $0.requests,
                    bandwidth: Int64($0.bytes ?? 0),
                    threats: $0.threats ?? 0
                )
            }
        let topCountries = mappedCountries.sorted { lhs, rhs in
            if lhs.requests == rhs.requests {
                return lhs.countryCode < rhs.countryCode
            }
            return lhs.requests > rhs.requests
        }

        let contentTypeMap = group.sum.contentTypeMap ?? []
        let mappedContentTypes = contentTypeMap
            .filter { $0.requests > 0 }
            .map {
                TrafficContentTypeBucket(
                    contentType: $0.edgeResponseContentTypeName,
                    requests: $0.requests,
                    bandwidth: Int64($0.bytes ?? 0)
                )
            }
        let topContentTypes = mappedContentTypes.sorted { lhs, rhs in
            if lhs.requests == rhs.requests {
                return lhs.contentType < rhs.contentType
            }
            return lhs.requests > rhs.requests
        }

        return TrafficInsightsSnapshot(
            cachedRequests: group.sum.cachedRequests ?? 0,
            cachedBandwidth: Int64(group.sum.cachedBytes ?? 0),
            threats: group.sum.threats ?? 0,
            pageViews: group.sum.pageViews ?? 0,
            uniques: group.uniq?.uniques ?? 0,
            health: health,
            topCountries: Array(topCountries.prefix(5)),
            topContentTypes: Array(topContentTypes.prefix(5))
        )
    }

    private static func parseGraphQLTimeslot(_ rawValue: String, range: DashboardTimeRange) -> Date? {
        if range.usesHourlyBuckets {
            return graphQLResponseDateFormatter.date(from: rawValue)
        }
        return graphQLDayFormatter.date(from: rawValue)
    }
}
