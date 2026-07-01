import Foundation

nonisolated struct PagesDomainCreateRequest: Encodable, Sendable {
    let name: String
}

nonisolated struct PagesProjectDomain: Identifiable, Decodable, Sendable {
    let id: String
    let certificateAuthority: String?
    let createdOn: Date?
    let domainID: String?
    let name: String
    let status: String?
    let validationData: PagesDomainValidationData?
    let verificationData: PagesDomainVerificationData?
    let zoneTag: String?

    enum CodingKeys: String, CodingKey {
        case id
        case certificateAuthority = "certificate_authority"
        case createdOn = "created_on"
        case domainID = "domain_id"
        case name
        case status
        case validationData = "validation_data"
        case verificationData = "verification_data"
        case zoneTag = "zone_tag"
    }

    var normalizedStatus: String {
        status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    var statusTitle: String {
        normalizedStatus.isEmpty ? "Unknown" : normalizedStatus.replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }

    var isActive: Bool {
        normalizedStatus == "active"
    }

    var isPending: Bool {
        ["initializing", "pending", "pending_deletion", "pending_validation", "moved"].contains(normalizedStatus)
    }

    var hasError: Bool {
        ["deactivated", "error"].contains(normalizedStatus)
            || validationData?.hasError == true
            || verificationData?.hasError == true
    }
}

nonisolated struct PagesDomainValidationData: Decodable, Sendable {
    let method: String?
    let status: String?
    let errorMessage: String?
    let txtName: String?
    let txtValue: String?

    enum CodingKeys: String, CodingKey {
        case method
        case status
        case errorMessage = "error_message"
        case txtName = "txt_name"
        case txtValue = "txt_value"
    }

    var summary: String {
        var parts: [String] = []
        if let method, method.isEmpty == false {
            parts.append(method.uppercased())
        }
        if let status, status.isEmpty == false {
            parts.append(status.replacingOccurrences(of: "_", with: " ").localizedCapitalized)
        }
        return parts.isEmpty ? "Validation unavailable" : parts.joined(separator: " · ")
    }

    var hasError: Bool {
        (errorMessage?.isEmpty == false)
            || ["error", "failed"].contains(status?.lowercased() ?? "")
    }
}

nonisolated struct PagesDomainVerificationData: Decodable, Sendable {
    let status: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case status
        case errorMessage = "error_message"
    }

    var summary: String {
        guard let status, status.isEmpty == false else {
            return "Verification unavailable"
        }
        return status.replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }

    var hasError: Bool {
        (errorMessage?.isEmpty == false)
            || ["error", "failed"].contains(status?.lowercased() ?? "")
    }
}
