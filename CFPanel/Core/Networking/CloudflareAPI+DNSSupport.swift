import Foundation

nonisolated struct DNSImportResponse: Decodable, Sendable {
    let recsAdded: Int?
    let totalRecordsParsed: Int?

    enum CodingKeys: String, CodingKey {
        case recsAdded = "recs_added"
        case totalRecordsParsed = "total_records_parsed"
    }
}

nonisolated struct DNSScanReviewResponse: Decodable, Sendable {
    let accepts: [DNSRecord]
    let rejects: [String]
}
