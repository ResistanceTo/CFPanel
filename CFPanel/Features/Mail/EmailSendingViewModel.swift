import Foundation
import Observation

@MainActor
@Observable
final class EmailSendingViewModel {
    @ObservationIgnored
    private let store: EmailSendingStore
    @ObservationIgnored
    private let loadingStore: LoadingStateStore
    @ObservationIgnored
    private let context: EmailWorkspaceContext

    init(
        store: EmailSendingStore,
        loadingStore: LoadingStateStore,
        context: EmailWorkspaceContext
    ) {
        self.store = store
        self.loadingStore = loadingStore
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var selectedZone: CloudflareZone? { context.selectedZone }
    var tokenVerification: TokenVerification? { context.tokenVerification }
    var lastRefreshAt: Date? { context.lastRefreshAt }
    var sendingSubdomains: [EmailSendingSubdomain] { store.subdomains }
    var sendingStatusMessage: String? { store.statusMessage }
    var isSendingUnavailable: Bool { store.isUnavailable }
    var isRefreshing: Bool { loadingStore.isRefreshingMail }

    func refreshEmailSendingCatalog(force: Bool = false) async {
        guard let zoneID = selectedZoneID else { return }
        guard force || context.isEmailSendingLoaded(for: zoneID) == false else { return }

        await context.withMailLoading {
            do {
                let subdomains = try await context.api.listEmailSendingSubdomains(zoneID: zoneID)
                store.subdomains = subdomains.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                store.isUnavailable = false
                store.statusMessage = subdomains.isEmpty ? "No Email Sending subdomains found." : nil
                context.markEmailSendingLoaded(zoneID: zoneID)
            } catch let error as CloudflareAPIError {
                store.subdomains = []
                if let unavailableMessage = unavailableMessage(for: error) {
                    store.isUnavailable = true
                    store.statusMessage = unavailableMessage
                    context.markEmailSendingLoaded(zoneID: zoneID)
                } else {
                    store.isUnavailable = false
                    store.statusMessage = error.localizedDescription
                }
            } catch {
                store.subdomains = []
                store.isUnavailable = false
                store.statusMessage = error.localizedDescription
            }
        }
    }

    func loadEmailSendingDNSRecords(subdomainID: String) async throws -> [EmailDNSRecord] {
        let zoneID = try context.requireSelectedZoneID("Select an active site before opening Email Sending.")
        return try await context.api.fetchEmailSendingDNSRecords(zoneID: zoneID, subdomainID: subdomainID)
    }

    private func unavailableMessage(for error: CloudflareAPIError) -> String? {
        switch error {
        case .httpStatus(404, let message), .httpStatus(403, let message), .api(let message):
            if message.localizedCaseInsensitiveContains("Unable to authenticate request") {
                return "Email Sending is unavailable for this zone, token, or Cloudflare plan."
            }
            return nil
        default:
            return nil
        }
    }
}
