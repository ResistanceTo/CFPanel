import Foundation
import Observation

@MainActor
@Observable
final class PagesDomainsViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    func loadPagesDomains(projectName: String) async throws -> [PagesProjectDomain] {
        let accountID = try context.requireAccountID("This token cannot access account-level Pages domain data.")

        return try await context.api.listPagesDomains(accountID: accountID, projectName: projectName)
            .sorted {
                if $0.isActive == $1.isActive {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.isActive && $1.isActive == false
            }
    }

    func createPagesDomain(projectName: String, domainName: String) async throws -> PagesProjectDomain {
        let accountID = try context.requireAccountID("This token cannot create Pages domains.")

        return try await context.api.createPagesDomain(
            accountID: accountID,
            projectName: projectName,
            domainName: domainName
        )
    }

    func retryPagesDomainValidation(projectName: String, domainName: String) async throws -> PagesProjectDomain {
        let accountID = try context.requireAccountID("This token cannot access account-level Pages domain data.")

        return try await context.api.retryPagesDomainValidation(
            accountID: accountID,
            projectName: projectName,
            domainName: domainName
        )
    }

    func deletePagesDomain(projectName: String, domainName: String) async throws {
        let accountID = try context.requireAccountID("This token cannot delete Pages domains.")
        try await context.api.deletePagesDomain(
            accountID: accountID,
            projectName: projectName,
            domainName: domainName
        )
    }
}
