import Foundation
import Observation

@MainActor
@Observable
final class PagesCatalogViewModel {
    @ObservationIgnored
    private let accountStore: AccountServicesStore
    @ObservationIgnored
    private let loadingStore: LoadingStateStore
    @ObservationIgnored
    private let context: AccountServicesContext

    init(
        accountStore: AccountServicesStore,
        loadingStore: LoadingStateStore,
        context: AccountServicesContext
    ) {
        self.accountStore = accountStore
        self.loadingStore = loadingStore
        self.context = context
    }

    var resolvedAccountID: String? {
        context.resolvedAccountID
    }

    var pagesProjects: [PagesProject] {
        accountStore.pagesProjects
    }

    var pagesStatusMessage: String? {
        accountStore.pagesStatusMessage
    }

    var isRefreshingPages: Bool {
        loadingStore.isRefreshingPages
    }

    func pagesProject(id: String) -> PagesProject? {
        pagesProjects.first { $0.id == id }
    }

    func isPagesLoaded(for accountID: String) -> Bool {
        context.isPagesLoaded(for: accountID)
    }

    func refreshPagesCatalog(force: Bool = false) async {
        guard let accountContext = context.validateAccountContext() else {
            accountStore.clearPages(statusMessage: context.invalidAccountContextMessage())
            return
        }

        let accountID = accountContext.accountID
        guard force || isPagesLoaded(for: accountID) == false else { return }
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        await context.withLoadingActivity(.pages) {
            let didRefresh = await refreshPagesProjects(accountID: accountID)
            guard didRefresh, context.isCurrent(requestContext) else { return }
            context.markPagesLoaded(accountID: accountID)
        }
    }

    @discardableResult
    private func refreshPagesProjects(accountID: String) async -> Bool {
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        do {
            let projects = try await context.api.listPagesProjects(accountID: accountID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Pages catalog response.")
                return false
            }

            accountStore.pagesProjects = projects.sorted {
                ($0.canonicalDeployment?.modifiedOn ?? .distantPast) > ($1.canonicalDeployment?.modifiedOn ?? .distantPast)
            }
            accountStore.pagesStatusMessage = projects.isEmpty ? "No Pages projects found." : nil
            return true
        } catch {
            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Pages catalog error.")
                return false
            }

            accountStore.pagesProjects = []
            accountStore.pagesStatusMessage = error.localizedDescription
            return false
        }
    }
}
