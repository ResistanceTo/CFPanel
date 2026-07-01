import Foundation

nonisolated struct WorkerScriptSettings: Decodable, Sendable {
    let bindings: [WorkerBinding]?
    let compatibilityDate: String?
    let compatibilityFlags: [String]?
    let limits: JSONValue?
    let logpush: Bool?
    let observability: JSONValue?
    let placement: JSONValue?
    let tags: [String]?
    let tailConsumers: [WorkerTailConsumer]?
    let usageModel: String?

    enum CodingKeys: String, CodingKey {
        case bindings
        case compatibilityDate = "compatibility_date"
        case compatibilityFlags = "compatibility_flags"
        case limits
        case logpush
        case observability
        case placement
        case tags
        case tailConsumers = "tail_consumers"
        case usageModel = "usage_model"
    }

    var resolvedBindings: [WorkerBinding] {
        (bindings ?? []).sorted {
            if $0.type == $1.type {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.type.localizedStandardCompare($1.type) == .orderedAscending
        }
    }

    var bindingTypeSummary: [String] {
        let grouped = Dictionary(grouping: resolvedBindings, by: \.type)
        return grouped
            .sorted {
                if $0.value.count == $1.value.count {
                    return $0.key < $1.key
                }
                return $0.value.count > $1.value.count
            }
            .map { "\($0.key) \($0.value.count)" }
    }
}

nonisolated struct WorkerBinding: Identifiable, Hashable, Decodable, Sendable {
    let name: String
    let type: String
    let rawValue: JSONValue

    var id: String { "\(type):\(name)" }

    var title: String {
        name
    }

    var typeTitle: String {
        type.replacingOccurrences(of: "_", with: " ").localizedUppercase
    }

    var summary: String? {
        guard case .object(let object) = rawValue else { return nil }

        let preferredKeys = [
            "namespace_id",
            "bucket_name",
            "queue_name",
            "database_name",
            "dataset",
            "service",
            "environment",
            "class_name",
            "index_name",
            "project_id",
            "id"
        ]

        for key in preferredKeys {
            if let value = object[key]?.stringValue, value.isEmpty == false {
                return value
            }
        }

        let remainingKeys = object.keys
            .filter { $0 != "name" && $0 != "type" }
            .sorted()

        return remainingKeys.isEmpty ? nil : remainingKeys.joined(separator: ", ")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        name = try container.decodeIfPresent(String.self, forKey: .init("name")) ?? "Unnamed Binding"
        type = try container.decodeIfPresent(String.self, forKey: .init("type")) ?? "unknown"

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        rawValue = .object(rawObject)
    }
}

nonisolated struct WorkerTailConsumer: Identifiable, Hashable, Decodable, Sendable {
    let service: String?
    let environment: String?
    let namespace: String?

    var id: String {
        [service, environment, namespace].compactMap { $0 }.joined(separator: ":")
    }
}
