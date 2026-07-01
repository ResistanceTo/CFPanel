import Foundation
import Observation

@MainActor
@Observable
final class PagesOperationsViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    func purgePagesBuildCache(projectName: String) async throws {
        let accountID = try context.requireAccountID("This token cannot purge Pages build cache.")
        try await context.api.purgePagesBuildCache(accountID: accountID, projectName: projectName)
    }

    func deletePagesProject(projectName: String) async throws {
        let accountID = try context.requireAccountID("This token cannot delete Pages projects.")
        try await context.api.deletePagesProject(accountID: accountID, projectName: projectName)
    }
}
