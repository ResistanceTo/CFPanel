import Foundation

nonisolated struct VectorizeIndex: Identifiable, Hashable, Decodable, Sendable {
    let name: String
    let description: String?
    let createdOn: Date?
    let modifiedOn: Date?
    let config: JSONValue?
    let rawValue: JSONValue

    var id: String { name }

    var dimensions: Int? {
        config?.objectValue?["dimensions"]?.intValue
    }

    var metric: String? {
        config?.objectValue?["metric"]?.stringValue
    }

    var preset: String? {
        config?.objectValue?["preset"]?.stringValue
            ?? config?.objectValue?["model"]?.stringValue
    }

    var metricTitle: String {
        guard let metric, metric.isEmpty == false else { return "Metric n/a" }
        return metric.replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }

    var configSummary: String {
        var parts: [String] = []
        if let dimensions {
            parts.append("\(dimensions) dims")
        }
        if let preset, preset.isEmpty == false {
            parts.append(preset)
        }
        if let metric, metric.isEmpty == false {
            parts.append(metric.replacingOccurrences(of: "_", with: " ").localizedCapitalized)
        }
        return parts.isEmpty ? "Configuration unavailable" : parts.joined(separator: "  ·  ")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        name = try container.decode(String.self, forKey: .init("name"))
        description = try container.decodeIfPresent(String.self, forKey: .init("description"))
        createdOn = try container.decodeIfPresent(Date.self, forKey: .init("created_on"))
        modifiedOn = try container.decodeIfPresent(Date.self, forKey: .init("modified_on"))
        config = try container.decodeIfPresent(JSONValue.self, forKey: .init("config"))

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        rawValue = .object(rawObject)
    }
}

nonisolated struct VectorizeMetadataIndexListResponse: Decodable, Sendable {
    let metadataIndexes: [VectorizeMetadataIndex]
}

nonisolated struct VectorizeMetadataIndex: Identifiable, Hashable, Decodable, Sendable {
    let propertyName: String?
    let indexType: String?
    let rawValue: JSONValue

    var id: String {
        propertyName ?? rawValue.prettyPrintedString
    }

    var propertyTitle: String {
        propertyName ?? "Unnamed Property"
    }

    var typeTitle: String {
        indexType?.replacingOccurrences(of: "_", with: " ").localizedCapitalized ?? "Unknown"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        propertyName =
            try container.decodeIfPresent(String.self, forKey: .init("propertyName"))
            ?? container.decodeIfPresent(String.self, forKey: .init("property_name"))
        indexType =
            try container.decodeIfPresent(String.self, forKey: .init("indexType"))
            ?? container.decodeIfPresent(String.self, forKey: .init("index_type"))

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        rawValue = .object(rawObject)
    }
}
