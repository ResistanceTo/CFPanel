import Foundation
import Observation

@MainActor
@Observable
final class WorkerReleasesViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    func loadWorkerReleaseSnapshot(scriptName: String) async throws -> WorkerReleaseSnapshot {
        let accountID = try context.requireAccountID("This token cannot access account-level Workers release data.")

        async let deploymentsResult = context.partialResult {
            try await self.context.api.listWorkerDeployments(accountID: accountID, scriptName: scriptName)
        }
        async let versionsResult = context.partialResult {
            try await self.context.api.listWorkerVersions(accountID: accountID, scriptName: scriptName)
        }

        let resolvedDeployments = await deploymentsResult
        let resolvedVersions = await versionsResult

        return WorkerReleaseSnapshot(
            deployments: resolvedDeployments.value ?? [],
            deploymentErrorMessage: resolvedDeployments.errorMessage,
            versions: resolvedVersions.value ?? [],
            versionErrorMessage: resolvedVersions.errorMessage
        )
    }
}
