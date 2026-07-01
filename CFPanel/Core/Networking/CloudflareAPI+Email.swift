import Foundation

extension CloudflareAPI {
    func fetchEmailRoutingSettings(zoneID: String) async throws -> EmailRoutingSettings {
        let result: JSONValue = try await request(path: "/zones/\(zoneID)/email/routing")
        return EmailRoutingSettings(resultValue: result)
    }

    func fetchEmailRoutingDNS(zoneID: String) async throws -> EmailRoutingDNSStatus {
        let result: JSONValue = try await request(path: "/zones/\(zoneID)/email/routing/dns")
        return EmailRoutingDNSStatus(resultValue: result)
    }

    func enableEmailRouting(zoneID: String) async throws -> EmailRoutingSettings {
        try await request(path: "/zones/\(zoneID)/email/routing/dns", method: "PATCH")
    }

    func listEmailRoutingRules(zoneID: String) async throws -> [EmailRoutingRule] {
        try await request(path: "/zones/\(zoneID)/email/routing/rules")
    }

    func fetchEmailRoutingCatchAll(zoneID: String) async throws -> EmailRoutingRule? {
        do {
            let rule: EmailRoutingRule = try await request(
                path: "/zones/\(zoneID)/email/routing/rules/catch_all"
            )
            return rule
        } catch let error as CloudflareAPIError {
            if case .httpStatus(let code, _) = error, code == 404 {
                return nil
            }
            throw error
        }
    }

    func updateEmailRoutingCatchAll(zoneID: String, destination: String) async throws -> EmailRoutingRule {
        try await request(
            path: "/zones/\(zoneID)/email/routing/rules/catch_all",
            method: "PUT",
            body: EmailRoutingRuleUpdateRequest(
                actions: [
                    EmailRoutingActionUpdate(type: "forward", value: [destination])
                ],
                enabled: true,
                matchers: [
                    EmailRoutingMatcherUpdate(type: "all")
                ],
                name: "Catch all"
            )
        )
    }

    func listEmailRoutingDestinationAddresses(accountID: String) async throws -> [EmailRoutingDestinationAddress] {
        try await request(path: "/accounts/\(accountID)/email/routing/addresses")
    }

    func createEmailRoutingDestinationAddress(accountID: String, email: String) async throws -> EmailRoutingDestinationAddress {
        try await request(
            path: "/accounts/\(accountID)/email/routing/addresses",
            method: "POST",
            body: EmailRoutingDestinationAddressCreateRequest(email: email)
        )
    }

    func listEmailSendingSubdomains(zoneID: String) async throws -> [EmailSendingSubdomain] {
        try await request(path: "/zones/\(zoneID)/email/security/sending_subdomains")
    }

    func fetchEmailSendingDNSRecords(zoneID: String, subdomainID: String) async throws -> [EmailDNSRecord] {
        try await request(
            path: "/zones/\(zoneID)/email/security/sending_subdomains/\(subdomainID)/dns"
        )
    }
}
