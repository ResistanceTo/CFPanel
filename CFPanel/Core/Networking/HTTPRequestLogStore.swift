import Foundation
import Observation

nonisolated struct HTTPRequestLogEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let method: String
    let pathAndQuery: String
    let statusCode: Int?
    let durationMilliseconds: Int
    let attempt: Int
    let errorMessage: String?

    var statusText: String {
        if let statusCode {
            return String(statusCode)
        }
        return "Failed"
    }

    var isFailure: Bool {
        if let statusCode {
            return statusCode >= 400
        }
        return true
    }

    var endpointKey: String {
        "\(method) \(pathOnly)"
    }

    private var pathOnly: String {
        pathAndQuery.split(separator: "?", maxSplits: 1).first.map(String.init) ?? pathAndQuery
    }
}

nonisolated struct HTTPRequestEndpointSummary: Identifiable, Hashable, Sendable {
    let endpoint: String
    let count: Int

    var id: String { endpoint }
}

@MainActor
@Observable
final class HTTPRequestLogStore {
    static let shared = HTTPRequestLogStore()

    private(set) var entries: [HTTPRequestLogEntry] = []
    private(set) var failureCount = 0
    private(set) var endpointSummaries: [HTTPRequestEndpointSummary] = []
    private let maxEntries = 500
    @ObservationIgnored
    private var endpointCounts: [String: Int] = [:]

    var totalRequestCount: Int {
        entries.count
    }

    private init() {}

    func record(
        method: String,
        url: URL?,
        statusCode: Int?,
        durationMilliseconds: Int,
        attempt: Int,
        errorMessage: String? = nil
    ) {
        let entry = HTTPRequestLogEntry(
            id: UUID(),
            timestamp: Date(),
            method: method,
            pathAndQuery: Self.redactedPathAndQuery(from: url),
            statusCode: statusCode,
            durationMilliseconds: durationMilliseconds,
            attempt: attempt,
            errorMessage: Self.redactedErrorMessage(errorMessage)
        )

        entries.insert(
            entry,
            at: 0
        )
        index(entry)

        if entries.count > maxEntries {
            let removedEntries = Array(entries.suffix(entries.count - maxEntries))
            entries.removeLast(removedEntries.count)
            for removedEntry in removedEntries {
                deindex(removedEntry)
            }
        }
    }

    func clear() {
        entries.removeAll()
        failureCount = 0
        endpointCounts.removeAll()
        endpointSummaries = []
    }

    func exportJSON(includeSuccessfulRequests: Bool = false) -> String {
        let export = HTTPRequestLogExport(
            exportedAt: Date(),
            totalRequestCount: totalRequestCount,
            failureCount: failureCount,
            entries: entries
                .filter { includeSuccessfulRequests || $0.isFailure }
                .map(HTTPRequestLogExportEntry.init(entry:))
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(export),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return text
    }

    nonisolated static func redactedPathAndQuery(from url: URL?) -> String {
        guard let url else { return "unknown-url" }
        var value = redactedPath(from: url)
        let queryNames = redactedQueryNames(from: url)
        if queryNames.isEmpty == false {
            value += "?\(queryNames.joined(separator: "&"))"
        }
        return value
    }

    nonisolated private static func redactedPath(from url: URL) -> String {
        let path = url.path(percentEncoded: false)
        guard path.isEmpty == false else { return "/" }
        let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        let redactedSegments = segments
            .enumerated()
            .map { index, segment in
                let previous = index > 0 ? segments[index - 1] : nil
                return redactedPathSegment(segment, previousSegment: previous)
            }

        return "/" + redactedSegments.joined(separator: "/")
    }

    nonisolated private static func redactedPathSegment(
        _ segment: String,
        previousSegment: String?
    ) -> String {
        if isKnownActionSegment(segment, after: previousSegment) {
            return segment
        }

        if let previousSegment,
           let placeholder = placeholder(after: previousSegment)
        {
            return placeholder
        }

        if isLikelyIdentifier(segment) {
            return "{id}"
        }

        return segment
    }

    nonisolated private static func placeholder(after segment: String) -> String? {
        switch segment {
        case "accounts":
            return "{account}"
        case "zones":
            return "{zone}"
        case "dns_records":
            return "{record}"
        case "namespaces":
            return "{namespace}"
        case "values":
            return "{key}"
        case "scripts":
            return "{script}"
        case "projects":
            return "{project}"
        case "deployments":
            return "{deployment}"
        case "routes":
            return "{route}"
        case "domains":
            return "{domain}"
        case "buckets":
            return "{bucket}"
        case "queues":
            return "{queue}"
        case "databases":
            return "{database}"
        case "database":
            return "{database}"
        case "indexes":
            return "{index}"
        case "configs":
            return "{config}"
        case "metadata":
            return "{key}"
        case "tokens":
            return "{token}"
        default:
            return nil
        }
    }

    nonisolated private static func isKnownActionSegment(
        _ segment: String,
        after previousSegment: String?
    ) -> Bool {
        switch previousSegment {
        case "dns_records":
            return ["export", "import", "scan"].contains(segment)
        case "tokens":
            return segment == "verify"
        default:
            return false
        }
    }

    nonisolated private static func isLikelyIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return false }

        let allowedScalars = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_"))
        return trimmed.unicodeScalars.allSatisfy { allowedScalars.contains($0) }
    }

    nonisolated private static func redactedQueryNames(from url: URL) -> [String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            return []
        }

        return queryItems.map { item in
            item.value == nil ? item.name : "\(item.name)=<redacted>"
        }
    }

    nonisolated private static func redactedErrorMessage(_ message: String?) -> String? {
        guard let message else { return nil }
        guard message.contains("failingURL=") else { return message }

        return message
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { part in
                let trimmedPart = part.trimmingCharacters(in: .whitespaces)
                guard trimmedPart.hasPrefix("failingURL=") else { return trimmedPart }
                return "failingURL=<redacted>"
            }
            .joined(separator: " | ")
    }

    private func index(_ entry: HTTPRequestLogEntry) {
        if entry.isFailure {
            failureCount += 1
        }

        endpointCounts[entry.endpointKey, default: 0] += 1
        rebuildEndpointSummaries()
    }

    private func deindex(_ entry: HTTPRequestLogEntry) {
        if entry.isFailure {
            failureCount = max(0, failureCount - 1)
        }

        if let count = endpointCounts[entry.endpointKey], count > 1 {
            endpointCounts[entry.endpointKey] = count - 1
        } else {
            endpointCounts.removeValue(forKey: entry.endpointKey)
        }
        rebuildEndpointSummaries()
    }

    private func rebuildEndpointSummaries() {
        endpointSummaries = endpointCounts
            .map { endpoint, count in
                HTTPRequestEndpointSummary(endpoint: endpoint, count: count)
            }
            .sorted {
                if $0.count == $1.count {
                    return $0.endpoint < $1.endpoint
                }
                return $0.count > $1.count
            }
    }
}

nonisolated private struct HTTPRequestLogExport: Encodable, Sendable {
    let exportedAt: Date
    let totalRequestCount: Int
    let failureCount: Int
    let entries: [HTTPRequestLogExportEntry]
}

nonisolated private struct HTTPRequestLogExportEntry: Encodable, Sendable {
    let timestamp: Date
    let method: String
    let pathAndQuery: String
    let statusCode: Int?
    let durationMilliseconds: Int
    let attempt: Int
    let errorMessage: String?

    init(entry: HTTPRequestLogEntry) {
        timestamp = entry.timestamp
        method = entry.method
        pathAndQuery = entry.pathAndQuery
        statusCode = entry.statusCode
        durationMilliseconds = entry.durationMilliseconds
        attempt = entry.attempt
        errorMessage = entry.errorMessage
    }
}
