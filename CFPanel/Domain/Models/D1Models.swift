import Foundation

nonisolated struct D1Database: Identifiable, Hashable, Decodable, Sendable {
    let uuid: String
    let name: String
    let createdAt: Date?
    let version: String?
    let numTables: Int?
    let fileSize: Int64?
    let runningInRegion: String?

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case createdAt = "created_at"
        case version
        case numTables = "num_tables"
        case fileSize = "file_size"
        case runningInRegion = "running_in_region"
    }

    var id: String { uuid }

    var versionTitle: String {
        guard let version, version.isEmpty == false else { return "Unknown" }
        return version
    }

    var regionTitle: String {
        guard let runningInRegion, runningInRegion.isEmpty == false else { return "Auto" }
        return runningInRegion.replacingOccurrences(of: "_", with: " ").localizedUppercase
    }
}

nonisolated struct D1DatabaseDetail: Identifiable, Decodable, Sendable {
    let uuid: String
    let name: String
    let createdAt: Date?
    let version: String?
    let numTables: Int?
    let fileSize: Int64?
    let runningInRegion: String?
    let rawValue: JSONValue

    var id: String { uuid }

    var versionTitle: String {
        guard let version, version.isEmpty == false else { return "Unknown" }
        return version
    }

    var regionTitle: String {
        guard let runningInRegion, runningInRegion.isEmpty == false else { return "Auto" }
        return runningInRegion.replacingOccurrences(of: "_", with: " ").localizedUppercase
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        uuid =
            try container.decodeIfPresent(String.self, forKey: .init("uuid"))
            ?? container.decode(String.self, forKey: .init("id"))
        name = try container.decode(String.self, forKey: .init("name"))
        createdAt =
            try container.decodeIfPresent(Date.self, forKey: .init("created_at"))
            ?? container.decodeIfPresent(Date.self, forKey: .init("created_on"))
        version = try container.decodeIfPresent(String.self, forKey: .init("version"))
        numTables = try container.decodeIfPresent(Int.self, forKey: .init("num_tables"))
        fileSize =
            try container.decodeIfPresent(Int64.self, forKey: .init("file_size"))
            ?? container.decodeIfPresent(Int64.self, forKey: .init("num_bytes"))
        runningInRegion = try container.decodeIfPresent(String.self, forKey: .init("running_in_region"))

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        rawValue = .object(rawObject)
    }
}
