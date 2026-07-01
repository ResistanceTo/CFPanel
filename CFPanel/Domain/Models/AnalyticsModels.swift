import Foundation

nonisolated enum DashboardTimeRange: String, CaseIterable, Identifiable, Codable, Sendable {
    case last24Hours
    case last7Days
    case last30Days

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last24Hours: "24H"
        case .last7Days: "7D"
        case .last30Days: "30D"
        }
    }

    var metricTitle: String {
        switch self {
        case .last24Hours: "24h"
        case .last7Days: "7d"
        case .last30Days: "30d"
        }
    }

    var usesHourlyBuckets: Bool {
        self == .last24Hours
    }
}

nonisolated enum DashboardTrendMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case requests
    case bandwidth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .requests: "Requests"
        case .bandwidth: "Bandwidth"
        }
    }
}

nonisolated struct DashboardSnapshot: Equatable, Sendable {
    let range: DashboardTimeRange
    let totalRequests: Int
    let totalBandwidth: Int64
    let timeseries: [TrafficPoint]
    let insights: TrafficInsightsSnapshot?

    var health: TrafficHealthSnapshot? {
        insights?.health
    }

    static let placeholder = DashboardSnapshot(
        range: .last24Hours,
        totalRequests: 0,
        totalBandwidth: 0,
        timeseries: [],
        insights: nil
    )
}

nonisolated struct TrafficPoint: Identifiable, Equatable, Sendable {
    let timestamp: Date
    let requests: Int
    let bandwidth: Int64

    var id: Date { timestamp }
}

nonisolated struct TrafficHealthSnapshot: Equatable, Sendable {
    let successfulRequests: Int
    let redirectedRequests: Int
    let clientErrorRequests: Int
    let serverErrorRequests: Int
    let totalBytes: Int64
    let statusBreakdown: [HTTPStatusBucket]

    var totalRequests: Int {
        successfulRequests + redirectedRequests + clientErrorRequests + serverErrorRequests
    }

    var errorRate: Double {
        let total = totalRequests
        guard total > 0 else { return 0 }
        return Double(clientErrorRequests + serverErrorRequests) / Double(total)
    }
}

nonisolated struct TrafficInsightsSnapshot: Equatable, Sendable {
    let cachedRequests: Int
    let cachedBandwidth: Int64
    let threats: Int
    let pageViews: Int
    let uniques: Int
    let health: TrafficHealthSnapshot
    let topCountries: [TrafficCountryBucket]
    let topContentTypes: [TrafficContentTypeBucket]

    var uncachedRequests: Int {
        max(health.totalRequests - cachedRequests, 0)
    }

    var uncachedBandwidth: Int64 {
        max(health.totalBytes - cachedBandwidth, 0)
    }

    var cacheHitRate: Double {
        let total = health.totalRequests
        guard total > 0 else { return 0 }
        return Double(cachedRequests) / Double(total)
    }

    var bandwidthCacheHitRate: Double {
        let total = health.totalBytes
        guard total > 0 else { return 0 }
        return Double(cachedBandwidth) / Double(total)
    }
}

nonisolated struct HTTPStatusBucket: Identifiable, Equatable, Sendable {
    let code: Int
    let requests: Int

    var id: Int { code }
}

nonisolated struct TrafficCountryBucket: Identifiable, Equatable, Sendable {
    let countryCode: String
    let requests: Int
    let bandwidth: Int64
    let threats: Int

    var id: String { countryCode }

    var title: String {
        Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
    }
}

nonisolated struct TrafficContentTypeBucket: Identifiable, Equatable, Sendable {
    let contentType: String
    let requests: Int
    let bandwidth: Int64

    var id: String { contentType }

    var title: String {
        contentType.isEmpty ? "Unknown" : contentType
    }
}
