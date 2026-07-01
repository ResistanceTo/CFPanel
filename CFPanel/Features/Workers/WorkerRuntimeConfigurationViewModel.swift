import Foundation
import Observation

@MainActor
@Observable
final class WorkerRuntimeConfigurationViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    func loadWorkerRuntimeConfiguration(scriptName: String) async throws -> WorkerRuntimeConfigurationSnapshot {
        let accountID = try context.requireAccountID("This token cannot access account-level Workers configuration data.")

        async let schedulesResult = context.partialResult {
            try await self.context.api.fetchWorkerSchedules(accountID: accountID, scriptName: scriptName)
        }
        async let settingsResult = context.partialResult {
            try await self.context.api.fetchWorkerScriptSettings(accountID: accountID, scriptName: scriptName)
        }

        let resolvedSchedules = await schedulesResult
        let resolvedSettings = await settingsResult

        return WorkerRuntimeConfigurationSnapshot(
            settings: resolvedSettings.value,
            settingsErrorMessage: resolvedSettings.errorMessage,
            schedules: resolvedSchedules.value,
            scheduleErrorMessage: resolvedSchedules.errorMessage
        )
    }
}
