import Foundation
import Observation

@MainActor
@Observable
final class WorkerVersionsViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    func loadWorkerVersionDetail(scriptName: String, versionID: String) async throws -> WorkerVersionDetail {
        let accountID = try context.requireAccountID("This token cannot access account-level Worker version data.")

        return try await context.api.fetchWorkerVersion(
            accountID: accountID,
            scriptName: scriptName,
            versionID: versionID
        )
    }
}
