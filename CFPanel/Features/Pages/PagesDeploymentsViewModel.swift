import Foundation
import Observation

@MainActor
@Observable
final class PagesDeploymentsViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    func loadPagesDeployments(projectName: String, environment: String? = nil) async throws -> [PagesDeployment] {
        let accountID = try context.requireAccountID("This token cannot access account-level Pages data.")

        return try await context.api.listPagesDeployments(
            accountID: accountID,
            projectName: projectName,
            environment: environment
        )
        .sorted { ($0.modifiedOn ?? .distantPast) > ($1.modifiedOn ?? .distantPast) }
    }

    func retryPagesDeployment(projectName: String, deploymentID: String) async throws -> PagesDeployment {
        let accountID = try context.requireAccountID("This token cannot access account-level Pages deployment actions.")

        return try await context.api.retryPagesDeployment(
            accountID: accountID,
            projectName: projectName,
            deploymentID: deploymentID
        )
    }

    func rollbackPagesDeployment(projectName: String, deploymentID: String) async throws -> PagesDeployment {
        let accountID = try context.requireAccountID("This token cannot access account-level Pages rollback actions.")

        return try await context.api.rollbackPagesDeployment(
            accountID: accountID,
            projectName: projectName,
            deploymentID: deploymentID
        )
    }

    func deletePagesDeployment(projectName: String, deploymentID: String) async throws {
        let accountID = try context.requireAccountID("This token cannot delete Pages deployments.")
        try await context.api.deletePagesDeployment(
            accountID: accountID,
            projectName: projectName,
            deploymentID: deploymentID
        )
    }
}
