import Foundation

nonisolated struct GraphQLResponse<DataPayload: Decodable & Sendable>: Decodable, Sendable {
    let data: DataPayload?
    let errors: [GraphQLError]?
}

nonisolated struct GraphQLError: Decodable, Sendable {
    let message: String
}

nonisolated struct DashboardGraphQLData: Decodable, Sendable {
    let viewer: Viewer

    nonisolated struct Viewer: Decodable, Sendable {
        let zones: [Zone]
    }

    nonisolated struct Zone: Decodable, Sendable {
        let httpRequestsAdaptiveGroups: [Group]
    }

    nonisolated struct Group: Decodable, Sendable {
        let count: Int
        let sum: Sum
        let dimensions: Dimensions
    }

    nonisolated struct Sum: Decodable, Sendable {
        let edgeResponseBytes: Int?
    }

    nonisolated struct Dimensions: Decodable, Sendable {
        let datetimeHour: Date?
    }
}

nonisolated struct DashboardTrafficInsightsGraphQLData: Decodable, Sendable {
    let viewer: Viewer

    nonisolated struct Viewer: Decodable, Sendable {
        let zones: [Zone]
    }

    nonisolated struct Zone: Decodable, Sendable {
        let totals: [Group]
    }

    nonisolated struct Group: Decodable, Sendable {
        let sum: Sum
        let uniq: Uniq?
    }

    nonisolated struct Sum: Decodable, Sendable {
        let requests: Int?
        let bytes: Int?
        let cachedBytes: Int?
        let cachedRequests: Int?
        let threats: Int?
        let pageViews: Int?
        let responseStatusMap: [ResponseStatus]?
        let countryMap: [CountryMap]?
        let contentTypeMap: [ContentTypeMap]?

        enum CodingKeys: String, CodingKey {
            case requests
            case bytes
            case cachedBytes
            case cachedRequests
            case threats
            case pageViews
            case responseStatusMap
            case countryMap
            case contentTypeMap
        }
    }

    nonisolated struct Uniq: Decodable, Sendable {
        let uniques: Int?
    }

    nonisolated struct ResponseStatus: Decodable, Sendable {
        let edgeResponseStatus: Int
        let requests: Int
    }

    nonisolated struct CountryMap: Decodable, Sendable {
        let clientCountryName: String
        let requests: Int
        let bytes: Int?
        let threats: Int?
    }

    nonisolated struct ContentTypeMap: Decodable, Sendable {
        let edgeResponseContentTypeName: String
        let requests: Int
        let bytes: Int?
    }
}

nonisolated struct DashboardTimeseriesGraphQLData: Decodable, Sendable {
    let viewer: Viewer

    nonisolated struct Viewer: Decodable, Sendable {
        let zones: [Zone]
    }

    nonisolated struct Zone: Decodable, Sendable {
        let series: [Group]
    }

    nonisolated struct Group: Decodable, Sendable {
        let dimensions: Dimensions
        let sum: Sum
    }

    nonisolated struct Dimensions: Decodable, Sendable {
        let timeslot: String?
    }

    nonisolated struct Sum: Decodable, Sendable {
        let requests: Int?
        let bytes: Int?
    }
}

nonisolated struct CombinedDashboardGraphQLData: Decodable, Sendable {
    let viewer: Viewer

    nonisolated struct Viewer: Decodable, Sendable {
        let zones: [Zone]
    }

    nonisolated struct Zone: Decodable, Sendable {
        let totals: [DashboardTrafficInsightsGraphQLData.Group]
        let series: [DashboardTimeseriesGraphQLData.Group]
    }
}

nonisolated struct GraphQLRequest: Encodable, Sendable {
    let query: String
    let variables: JSONValue
}

nonisolated struct GraphQLErrorEnvelope: Decodable, Sendable {
    let errors: [GraphQLError]?
}

nonisolated struct WorkersUsageGraphQLData: Decodable, Sendable {
    let viewer: Viewer

    nonisolated struct Viewer: Decodable, Sendable {
        let accounts: [Account]
    }

    nonisolated struct Account: Decodable, Sendable {
        let month: [UsageGroup]?
        let today: [UsageGroup]?
    }

    nonisolated struct UsageGroup: Decodable, Sendable {
        let sum: UsageSum?
        let quantiles: UsageQuantiles?
    }

    nonisolated struct UsageSum: Decodable, Sendable {
        let requests: Int?
        let errors: Int?
        let subrequests: Int?
    }

    nonisolated struct UsageQuantiles: Decodable, Sendable {
        let cpuTimeP50: Double?
        let cpuTimeP99: Double?
    }
}

nonisolated struct WorkersCPUTimeGraphQLData: Decodable, Sendable {
    let viewer: Viewer

    nonisolated struct Viewer: Decodable, Sendable {
        let accounts: [Account]
    }

    nonisolated struct Account: Decodable, Sendable {
        let month: [CPUGroup]?
        let today: [CPUGroup]?
    }

    nonisolated struct CPUGroup: Decodable, Sendable {
        let sum: CPUSum?
    }

    nonisolated struct CPUSum: Decodable, Sendable {
        let cpuTimeUs: Double?
    }
}
