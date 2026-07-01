import Foundation
import Observation

@MainActor
@Observable
final class PagesDeploymentLogsViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    func loadPagesDeploymentLogs(projectName: String, deploymentID: String) async throws -> PagesDeploymentLogResponse {
        let accountID = try context.requireAccountID("This token cannot access account-level Pages logs.")

        return try await context.api.fetchPagesDeploymentLogs(
            accountID: accountID,
            projectName: projectName,
            deploymentID: deploymentID
        )
    }
}
