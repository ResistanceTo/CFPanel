import Foundation

nonisolated enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON payload.")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var prettyPrintedString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(self),
              let value = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return value
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        guard case .number(let value) = self else { return nil }
        return Int(value)
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }
}

nonisolated struct AnyCodingKey: CodingKey, Hashable, Sendable {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension Int64 {
    nonisolated var bytesFormatted: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .binary)
    }

    nonisolated var compactAbbreviated: String {
        Self.compactAbbreviatedString(for: self)
    }

    nonisolated private static func compactAbbreviatedString(for value: Int64) -> String {
        let absoluteValue = abs(Double(value))
        guard absoluteValue >= 100_000 else {
            return value.formatted(.number.grouping(.automatic))
        }

        let units: [(threshold: Double, suffix: String)] = [
            (1_000_000_000_000, "t"),
            (1_000_000_000, "b"),
            (1_000_000, "m"),
            (1_000, "k")
        ]

        guard let unit = units.first(where: { absoluteValue >= $0.threshold }) else {
            return value.formatted(.number.grouping(.automatic))
        }

        let scaledValue = Double(value) / unit.threshold
        let fractionDigits: Int
        switch abs(scaledValue) {
        case 100...:
            fractionDigits = 0
        case 10...:
            fractionDigits = 1
        default:
            fractionDigits = 2
        }

        return scaledValue.formatted(
            .number
                .precision(.fractionLength(0 ... fractionDigits))
                .grouping(.never)
        ) + unit.suffix
    }
}

extension Int {
    nonisolated var compactAbbreviated: String {
        Int64(self).compactAbbreviated
    }
}

extension String {
    nonisolated var middleEllipsizedToken: String {
        guard count > 14 else { return self }

        let prefixPart = prefix(6)
        let suffixPart = suffix(4)
        return "\(prefixPart)...\(suffixPart)"
    }
}
