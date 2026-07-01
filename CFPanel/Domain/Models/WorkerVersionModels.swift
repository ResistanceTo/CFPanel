import Foundation

nonisolated struct WorkerScript: Identifiable, Decodable, Sendable {
    let id: String
    let createdOn: Date?
    let modifiedOn: Date?
    let hasAssets: Bool?
    let hasModules: Bool?
    let usageModel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case hasAssets = "has_assets"
        case hasModules = "has_modules"
        case usageModel = "usage_model"
    }
}

nonisolated struct WorkerDeploymentList: Decodable, Sendable {
    let deployments: [WorkerDeployment]
}

nonisolated struct WorkerDeployment: Identifiable, Decodable, Sendable {
    let id: String
    let createdOn: Date?
    let source: String?
    let strategy: String?
    let versions: [WorkerDeploymentVersion]
    let annotations: [String: String]?
    let authorEmail: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdOn = "created_on"
        case source
        case strategy
        case versions
        case annotations
        case authorEmail = "author_email"
    }

    var deploymentMessage: String? {
        annotations?["workers/message"]
    }

    var triggeredBy: String? {
        annotations?["workers/triggered_by"]
    }
}

nonisolated struct WorkerDeploymentVersion: Identifiable, Decodable, Sendable {
    let versionID: String
    let percentage: Double

    enum CodingKeys: String, CodingKey {
        case versionID = "version_id"
        case percentage
    }

    var id: String { versionID }
}

nonisolated struct WorkerVersion: Identifiable, Decodable, Sendable {
    let id: String
    let number: Double?
    let metadata: WorkerVersionMetadata?

    var versionNumberTitle: String {
        if let number {
            return "v\(Int(number))"
        }
        return "Unnumbered"
    }

    var createdOn: Date? {
        metadata?.createdOn
    }

    var modifiedOn: Date? {
        metadata?.modifiedOn
    }

    var sourceTitle: String? {
        metadata?.source?.replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }
}

nonisolated struct WorkerVersionMetadata: Decodable, Sendable {
    let authorEmail: String?
    let createdOn: Date?
    let modifiedOn: Date?
    let source: String?
    let annotations: [String: String]?

    enum CodingKeys: String, CodingKey {
        case authorEmail = "author_email"
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case source
        case annotations
    }

    var deploymentMessage: String? {
        annotations?["workers/message"]
    }

    var triggeredBy: String? {
        annotations?["workers/triggered_by"]
    }
}

nonisolated struct WorkerVersionDetail: Identifiable, Decodable, Sendable {
    let id: String
    let number: Double?
    let metadata: WorkerVersionMetadata?
    let startupTimeMS: Int?
    let resources: WorkerVersionResources?

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case metadata
        case startupTimeMS = "startup_time_ms"
        case resources
    }

    var versionNumberTitle: String {
        if let number {
            return "v\(Int(number))"
        }
        return id.middleEllipsizedToken
    }
}

nonisolated struct WorkerVersionResources: Decodable, Sendable {
    let bindings: [WorkerBinding]?
    let script: WorkerVersionScriptResources?
    let scriptRuntime: WorkerVersionRuntime?
    let scriptConfig: WorkerVersionConfig?

    enum CodingKeys: String, CodingKey {
        case bindings
        case script
        case scriptRuntime = "script_runtime"
        case scriptConfig = "script_config"
    }
}

nonisolated struct WorkerVersionScriptResources: Decodable, Sendable {
    let etag: String?
    let handlers: [String]?
    let lastDeployedFrom: String?

    enum CodingKeys: String, CodingKey {
        case etag
        case handlers
        case lastDeployedFrom = "last_deployed_from"
    }
}

nonisolated struct WorkerVersionRuntime: Decodable, Sendable {
    let usageModel: String?
    let compatibilityDate: String?
    let compatibilityFlags: [String]?

    enum CodingKeys: String, CodingKey {
        case usageModel = "usage_model"
        case compatibilityDate = "compatibility_date"
        case compatibilityFlags = "compatibility_flags"
    }
}

nonisolated struct WorkerVersionConfig: Decodable, Sendable {
    let limits: JSONValue?
    let placement: JSONValue?
    let observability: JSONValue?
}

nonisolated struct WorkerVersionListResult: Decodable, Sendable {
    let items: [WorkerVersion]?
}
