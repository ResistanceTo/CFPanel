import Foundation
import SwiftUI

nonisolated enum CloudflareAPIError: LocalizedError, Equatable {
    case missingToken
    case invalidRequest
    case invalidResponse
    case unauthorized
    case rateLimited
    case api(String)
    case httpStatus(Int, String)
    case decoding(String)
    case graphQL(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Please add a Cloudflare API token first."
        case .invalidRequest:
            return "The Cloudflare request could not be created."
        case .invalidResponse:
            return "Cloudflare returned an invalid response."
        case .unauthorized:
            return "Your Cloudflare authorization is no longer valid. Please sign in again."
        case .rateLimited:
            return "Cloudflare rate limited this request. Please retry in a moment."
        case .api(let message):
            return message
        case .httpStatus(let code, let message):
            return "HTTP \(code): \(message)"
        case .decoding(let message):
            return message
        case .graphQL(let message):
            return message
        }
    }
}

nonisolated struct TokenVerification: Decodable, Sendable {
    nonisolated enum Status: String, Codable, Sendable {
        case active
        case disabled
        case expired

        var title: LocalizedStringResource {
            switch self {
            case .active: "Active"
            case .disabled: "Disabled"
            case .expired: "Expired"
            }
        }

        var tint: Color {
            switch self {
            case .active:
                .green
            case .disabled:
                .orange
            case .expired:
                .red
            }
        }
    }

    let id: String
    let status: Status
    let expiresOn: Date?
    let notBefore: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case expiresOn = "expires_on"
        case notBefore = "not_before"
    }
}

nonisolated struct CloudflareEnvelope<Result: Decodable>: Decodable {
    let success: Bool
    let errors: [CloudflareMessage]?
    let messages: [CloudflareMessage]?
    let result: Result?
    let resultInfo: CloudflareResultInfo?

    enum CodingKeys: String, CodingKey {
        case success
        case errors
        case messages
        case result
        case resultInfo = "result_info"
    }
}

nonisolated struct CloudflareMessage: Decodable, Sendable {
    let code: Int?
    let message: String

    var diagnosticText: String {
        if let code {
            return "[\(code)] \(message)"
        }
        return message
    }
}

nonisolated struct CloudflareResultInfo: Decodable, Sendable {
    let count: Int?
    let page: Int?
    let perPage: Int?
    let totalCount: Int?
    let cursor: String?
    let cursors: CloudflareCursorInfo?

    enum CodingKeys: String, CodingKey {
        case count
        case page
        case perPage = "per_page"
        case totalCount = "total_count"
        case cursor
        case cursors
    }

    var nextCursor: String? {
        let resolvedCursor = cursor ?? cursors?.after
        guard let resolvedCursor, resolvedCursor.isEmpty == false else {
            return nil
        }
        return resolvedCursor
    }
}

nonisolated struct CloudflareCursorInfo: Decodable, Sendable {
    let after: String?
    let before: String?
}

nonisolated struct DeleteResponse: Decodable, Sendable {
    let id: String
}

nonisolated struct MultipartFormField: Sendable {
    let name: String
    let data: Data
    let fileName: String?
    let mimeType: String

    init(name: String, data: Data, fileName: String? = nil, mimeType: String) {
        self.name = name
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

nonisolated struct EmptyPayload: Decodable, Sendable {}

nonisolated struct EmptyRequest: Encodable, Sendable {}
