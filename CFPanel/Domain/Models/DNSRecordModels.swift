import Foundation
import SwiftUI

nonisolated enum SupportedDNSRecordType: String, CaseIterable, Codable, Identifiable, Hashable {
    case a = "A"
    case aaaa = "AAAA"
    case caa = "CAA"
    case cert = "CERT"
    case cname = "CNAME"
    case dnskey = "DNSKEY"
    case ds = "DS"
    case https = "HTTPS"
    case loc = "LOC"
    case mx = "MX"
    case naptr = "NAPTR"
    case ns = "NS"
    case openpgpkey = "OPENPGPKEY"
    case ptr = "PTR"
    case smimea = "SMIMEA"
    case srv = "SRV"
    case sshfp = "SSHFP"
    case svcb = "SVCB"
    case tlsa = "TLSA"
    case txt = "TXT"
    case uri = "URI"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: rawValue)
    }

    var contentTitle: LocalizedStringResource {
        switch self {
        case .caa: "Tag"
        case .cert: "Certificate"
        case .dnskey: "Public Key"
        case .ds: "Digest"
        case .loc: "Coordinates"
        case .naptr: "Replacement"
        case .openpgpkey: "Public Key"
        case .smimea, .tlsa: "Certificate Association Data"
        case .sshfp: "Fingerprint"
        case .txt: "Value"
        case .uri: "Target URI"
        default: "Content"
        }
    }

    var guidance: LocalizedStringResource {
        switch self {
        case .a: "IPv4 address, for example 192.0.2.1."
        case .aaaa: "IPv6 address, for example 2001:db8::1."
        case .caa: "Use Tag for issue/issuewild/iodef and Value for the CA or contact value."
        case .cert: "Use Certificate for the base64 certificate payload."
        case .cname: "Canonical hostname target."
        case .dnskey: "DNSSEC key material. Fill Flags, Protocol, Algorithm, and Public Key."
        case .ds: "DNSSEC delegation signer. Fill Key Tag, Algorithm, Digest Type, and Digest."
        case .https: "HTTPS service binding. Fill Priority, Target, and optional parameters in Value."
        case .loc: "Location record content. Advanced users can paste Cloudflare-compatible LOC data."
        case .mx: "Mail exchanger hostname. Priority is required."
        case .naptr: "Fill Order, Preference, Flags, Service, Regexp, and Replacement."
        case .ns: "Authoritative nameserver hostname."
        case .openpgpkey: "OPENPGPKEY public key payload."
        case .ptr: "Pointer hostname."
        case .smimea: "Fill Usage, Selector, Matching Type, and certificate association data."
        case .srv: "Fill Priority, Weight, Port, and Target."
        case .sshfp: "Fill Algorithm, Fingerprint Type, and Fingerprint."
        case .svcb: "Service binding. Fill Priority, Target, and optional parameters in Value."
        case .tlsa: "Fill Usage, Selector, Matching Type, and certificate association data."
        case .txt: "TXT value. Quotes are not needed."
        case .uri: "Fill Priority, Weight, and Target URI."
        }
    }

    var supportsPriority: Bool {
        [.https, .mx, .srv, .svcb, .uri].contains(self)
    }

    var supportsProxied: Bool {
        switch self {
        case .a, .aaaa, .cname:
            true
        default:
            false
        }
    }

    var dataFields: [DNSRecordDataField] {
        switch self {
        case .caa:
            [
                .init(key: "flags", title: "Flags", placeholder: "0", valueKind: .integer),
                .init(key: "tag", title: "Tag", placeholder: "issue"),
                .init(key: "value", title: "Value", placeholder: "letsencrypt.org")
            ]
        case .cert:
            [
                .init(key: "type", title: "Certificate Type", placeholder: "1", valueKind: .integer),
                .init(key: "key_tag", title: "Key Tag", placeholder: "12345", valueKind: .integer),
                .init(key: "algorithm", title: "Algorithm", placeholder: "8", valueKind: .integer),
                .init(key: "certificate", title: "Certificate", placeholder: "Base64 certificate")
            ]
        case .dnskey:
            [
                .init(key: "flags", title: "Flags", placeholder: "257", valueKind: .integer),
                .init(key: "protocol", title: "Protocol", placeholder: "3", valueKind: .integer),
                .init(key: "algorithm", title: "Algorithm", placeholder: "13", valueKind: .integer),
                .init(key: "public_key", title: "Public Key", placeholder: "Base64 public key")
            ]
        case .ds:
            [
                .init(key: "key_tag", title: "Key Tag", placeholder: "12345", valueKind: .integer),
                .init(key: "algorithm", title: "Algorithm", placeholder: "13", valueKind: .integer),
                .init(key: "digest_type", title: "Digest Type", placeholder: "2", valueKind: .integer),
                .init(key: "digest", title: "Digest", placeholder: "Digest value")
            ]
        case .https, .svcb:
            [
                .init(key: "priority", title: "Priority", placeholder: "1", valueKind: .integer),
                .init(key: "target", title: "Target", placeholder: "."),
                .init(key: "value", title: "Value", placeholder: "alpn=h2 ipv4hint=192.0.2.1", isRequired: false)
            ]
        case .naptr:
            [
                .init(key: "order", title: "Order", placeholder: "100", valueKind: .integer),
                .init(key: "preference", title: "Preference", placeholder: "10", valueKind: .integer),
                .init(key: "flags", title: "Flags", placeholder: "U"),
                .init(key: "service", title: "Service", placeholder: "E2U+sip"),
                .init(key: "regexp", title: "Regexp", placeholder: "!^.*$!sip:info@example.com!", isRequired: false),
                .init(key: "replacement", title: "Replacement", placeholder: ".")
            ]
        case .smimea, .tlsa:
            [
                .init(key: "usage", title: "Usage", placeholder: "3", valueKind: .integer),
                .init(key: "selector", title: "Selector", placeholder: "1", valueKind: .integer),
                .init(key: "matching_type", title: "Matching Type", placeholder: "1", valueKind: .integer),
                .init(key: "certificate", title: "Certificate Association Data", placeholder: "Hex data")
            ]
        case .srv:
            [
                .init(key: "priority", title: "Priority", placeholder: "10", valueKind: .integer),
                .init(key: "weight", title: "Weight", placeholder: "5", valueKind: .integer),
                .init(key: "port", title: "Port", placeholder: "443", valueKind: .integer),
                .init(key: "target", title: "Target", placeholder: "server.example.com")
            ]
        case .sshfp:
            [
                .init(key: "algorithm", title: "Algorithm", placeholder: "4", valueKind: .integer),
                .init(key: "type", title: "Fingerprint Type", placeholder: "2", valueKind: .integer),
                .init(key: "fingerprint", title: "Fingerprint", placeholder: "Fingerprint")
            ]
        case .uri:
            [
                .init(key: "priority", title: "Priority", placeholder: "10", valueKind: .integer),
                .init(key: "weight", title: "Weight", placeholder: "1", valueKind: .integer),
                .init(key: "target", title: "Target URI", placeholder: "https://example.com/")
            ]
        default:
            []
        }
    }

    var usesStructuredData: Bool {
        dataFields.isEmpty == false
    }
}

nonisolated struct DNSRecordDataField: Identifiable, Sendable {
    enum ValueKind: Sendable {
        case string
        case integer
    }

    let key: String
    let title: LocalizedStringResource
    let placeholder: String
    let valueKind: ValueKind
    let isRequired: Bool

    init(
        key: String,
        title: LocalizedStringResource,
        placeholder: String,
        valueKind: ValueKind = .string,
        isRequired: Bool = true
    ) {
        self.key = key
        self.title = title
        self.placeholder = placeholder
        self.valueKind = valueKind
        self.isRequired = isRequired
    }

    var id: String { key }
}

nonisolated struct DNSRecordDraft: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var recordID: String?
    var type: SupportedDNSRecordType = .a
    var name = ""
    var content = ""
    var ttl = 1
    var proxied = false
    var priority: Int?
    var comment = ""
    var data: [String: String] = [:]

    init() {}

    init(record: DNSRecord) {
        recordID = record.id
        type = record.supportedType ?? .a
        name = record.name
        content = record.content ?? ""
        ttl = record.ttl
        proxied = record.proxied ?? false
        priority = record.priority
        comment = record.comment ?? ""
        data = record.dataValues
    }

    var resolvedTTL: Int {
        ttl <= 0 ? 1 : ttl
    }

    var resolvedPriority: Int? {
        type.supportsPriority ? max(priority ?? 10, 0) : nil
    }

    var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedData: [String: String] {
        data.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var usesStructuredData: Bool {
        type.usesStructuredData
    }

    var validationError: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Record name is required."
        }

        if usesStructuredData {
            for field in type.dataFields where field.isRequired {
                if trimmedData[field.key]?.isEmpty != false {
                    return "\(String(localized: field.title)) is required."
                }
            }

            for field in type.dataFields where field.valueKind == .integer {
                guard let value = trimmedData[field.key], value.isEmpty == false else { continue }
                guard Int(value) != nil else {
                    return "\(String(localized: field.title)) must be a number."
                }
            }
        } else if trimmedContent.isEmpty {
            return "Record content is required."
        }

        if resolvedTTL < 1 {
            return "TTL must be at least 1."
        }

        if let resolvedPriority, resolvedPriority < 0 {
            return "Priority must be zero or greater."
        }

        return nil
    }
}

nonisolated struct DNSRecord: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let zoneID: String?
    let zoneName: String?
    let name: String
    let type: String
    let content: String?
    let ttl: Int
    let proxied: Bool?
    let priority: Int?
    let comment: String?
    let data: JSONValue?
    let modifiedOn: Date?
    let rawValue: JSONValue

    var supportedType: SupportedDNSRecordType? {
        SupportedDNSRecordType(rawValue: type.uppercased())
    }

    var normalizedType: String {
        type.uppercased()
    }

    var isUnsupported: Bool {
        supportedType == nil
    }

    var isWebRecord: Bool {
        [.a, .aaaa, .cname].contains(supportedType)
    }

    var isDNSOnlyWebRecord: Bool {
        isWebRecord && proxied == false
    }

    var isWildcard: Bool {
        name == "*" || name.hasPrefix("*.")
    }

    var needsAttention: Bool {
        isUnsupported || isDNSOnlyWebRecord || isWildcard
    }

    var proxyStatusTitle: String {
        if isWebRecord == false {
            return "Not Applicable"
        }
        return proxied == true ? "Proxied" : "DNS Only"
    }

    var ttlTitle: String {
        TTLSelection.title(for: ttl)
    }

    var attentionReasons: [String] {
        var reasons: [String] = []

        if isDNSOnlyWebRecord {
            reasons.append("Web-facing record is DNS only")
        }

        if isWildcard {
            reasons.append("Wildcard record can affect broad hostname ranges")
        }

        if isUnsupported {
            reasons.append("Record uses raw JSON fallback in this client")
        }

        return reasons
    }

    var summary: String {
        if let content, content.isEmpty == false {
            return content
        }

        if let dataSummary {
            return dataSummary
        }

        return "Unsupported payload"
    }

    var dataValues: [String: String] {
        guard let object = data?.objectValue else { return [:] }
        return object.reduce(into: [:]) { partialResult, pair in
            switch pair.value {
            case .string(let value):
                partialResult[pair.key] = value
            case .number(let value):
                if value.rounded() == value {
                    partialResult[pair.key] = Int(value).formatted()
                } else {
                    partialResult[pair.key] = value.formatted()
                }
            case .bool(let value):
                partialResult[pair.key] = value ? "true" : "false"
            case .array, .object:
                partialResult[pair.key] = pair.value.prettyPrintedString
            case .null:
                break
            }
        }
    }

    private var dataSummary: String? {
        let values = dataValues
        guard values.isEmpty == false else { return nil }
        return values.keys.sorted().compactMap { key in
            guard let value = values[key], value.isEmpty == false else { return nil }
            return "\(key)=\(value)"
        }
        .joined(separator: "  ·  ")
    }

    var rawJSON: String {
        rawValue.prettyPrintedString
    }

    var scanReviewAcceptPayload: JSONValue? {
        guard case .object(let object) = rawValue else {
            return nil
        }

        let removableKeys: Set<String> = [
            "id",
            "created_on",
            "modified_on",
            "comment_modified_on",
            "tags_modified_on",
            "meta",
            "proxiable",
            "locked",
            "zone_id",
            "zone_name"
        ]

        let filtered = object.filter { removableKeys.contains($0.key) == false }
        return .object(filtered)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        id = try container.decode(String.self, forKey: .init("id"))
        zoneID = try container.decodeIfPresent(String.self, forKey: .init("zone_id"))
        zoneName = try container.decodeIfPresent(String.self, forKey: .init("zone_name"))
        name = try container.decode(String.self, forKey: .init("name"))
        type = try container.decode(String.self, forKey: .init("type"))
        content = try container.decodeIfPresent(String.self, forKey: .init("content"))
        ttl = try container.decodeIfPresent(Int.self, forKey: .init("ttl")) ?? 1
        proxied = try container.decodeIfPresent(Bool.self, forKey: .init("proxied"))
        priority = try container.decodeIfPresent(Int.self, forKey: .init("priority"))
        comment = try container.decodeIfPresent(String.self, forKey: .init("comment"))
        data = try container.decodeIfPresent(JSONValue.self, forKey: .init("data"))
        modifiedOn = try container.decodeIfPresent(Date.self, forKey: .init("modified_on"))

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        rawValue = .object(rawObject)
    }
}
