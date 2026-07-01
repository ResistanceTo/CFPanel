import Foundation

nonisolated struct R2BucketList: Decodable, Sendable {
    let buckets: [R2Bucket]
}

nonisolated struct R2Bucket: Identifiable, Hashable, Decodable, Sendable {
    let name: String
    let creationDate: Date?
    let location: String?
    let storageClass: String?
    let jurisdiction: String?

    enum CodingKeys: String, CodingKey {
        case name
        case creationDate = "creation_date"
        case location
        case storageClass = "storage_class"
        case jurisdiction
    }

    var id: String { name }

    var locationTitle: String {
        guard let location, location.isEmpty == false else { return "Default" }
        return location.replacingOccurrences(of: "_", with: " ").localizedUppercase
    }

    var storageClassTitle: String {
        guard let storageClass, storageClass.isEmpty == false else { return "Standard" }
        return storageClass.replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }

    var jurisdictionTitle: String? {
        guard let jurisdiction, jurisdiction.isEmpty == false else { return nil }
        return jurisdiction.replacingOccurrences(of: "_", with: " ").localizedUppercase
    }
}

nonisolated struct R2BucketDetail: Identifiable, Decodable, Sendable {
    let name: String
    let creationDate: Date?
    let location: String?
    let storageClass: String?
    let jurisdiction: String?
    let lockEnabled: Bool?
    let rawValue: JSONValue

    var id: String { name }

    var locationTitle: String {
        guard let location, location.isEmpty == false else { return "Default" }
        return location.replacingOccurrences(of: "_", with: " ").localizedUppercase
    }

    var storageClassTitle: String {
        guard let storageClass, storageClass.isEmpty == false else { return "Standard" }
        return storageClass.replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }

    var jurisdictionTitle: String? {
        guard let jurisdiction, jurisdiction.isEmpty == false else { return nil }
        return jurisdiction.replacingOccurrences(of: "_", with: " ").localizedUppercase
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        name = try container.decode(String.self, forKey: .init("name"))
        creationDate = try container.decodeIfPresent(Date.self, forKey: .init("creation_date"))
        location = try container.decodeIfPresent(String.self, forKey: .init("location"))
        storageClass = try container.decodeIfPresent(String.self, forKey: .init("storage_class"))
        jurisdiction = try container.decodeIfPresent(String.self, forKey: .init("jurisdiction"))
        lockEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .init("lock_enabled"))
            ?? container.decodeIfPresent(Bool.self, forKey: .init("object_lock_enabled"))

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        rawValue = .object(rawObject)
    }
}
