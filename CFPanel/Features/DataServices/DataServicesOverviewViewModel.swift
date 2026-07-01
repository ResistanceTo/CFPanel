import Foundation
import Observation

@MainActor
@Observable
final class DataServicesOverviewViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    var resolvedAccountID: String? {
        context.resolvedAccountID
    }
}
