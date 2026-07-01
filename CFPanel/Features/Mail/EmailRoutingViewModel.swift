import Foundation
import Observation

@MainActor
@Observable
final class EmailRoutingViewModel {
    @ObservationIgnored
    private let store: EmailRoutingStore
    @ObservationIgnored
    private let loadingStore: LoadingStateStore
    @ObservationIgnored
    private let context: EmailWorkspaceContext

    init(
        store: EmailRoutingStore,
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
    var resolvedAccountID: String? { context.resolvedAccountID }
    var routingSettings: EmailRoutingSettings? { store.settings }
    var routingDNS: EmailRoutingDNSStatus { store.dns }
    var routingRules: [EmailRoutingRule] { store.rules }
    var routingCatchAll: EmailRoutingRule? { store.catchAll }
    var routingStatusMessage: String? { store.statusMessage }
    var destinationAddresses: [EmailRoutingDestinationAddress] { store.destinationAddresses }
    var destinationAddressesStatusMessage: String? { store.destinationAddressesStatusMessage }
    var isRefreshing: Bool { loadingStore.isRefreshingMail }

    func refreshEmailRoutingWorkspace(force: Bool = false) async {
        guard let zoneID = selectedZoneID else { return }

        let accountID = resolvedAccountID
        let shouldLoadAddresses: Bool
        if let accountID {
            shouldLoadAddresses = force || context.isEmailDestinationAddressesLoaded(for: accountID) == false
        } else {
            shouldLoadAddresses = false
        }

        guard force || context.isEmailRoutingLoaded(for: zoneID) == false || shouldLoadAddresses else { return }

        await context.withMailLoading {
            async let settingsResult = context.partialResult {
                try await self.context.api.fetchEmailRoutingSettings(zoneID: zoneID)
            }
            async let dnsResult = context.partialResult {
                try await self.context.api.fetchEmailRoutingDNS(zoneID: zoneID)
            }
            async let rulesResult = context.partialResult {
                try await self.context.api.listEmailRoutingRules(zoneID: zoneID)
            }
            async let catchAllResult = context.partialResult {
                try await self.context.api.fetchEmailRoutingCatchAll(zoneID: zoneID)
            }

            let resolvedSettingsResult = await settingsResult
            let resolvedDNSResult = await dnsResult
            let resolvedRulesResult = await rulesResult
            let resolvedCatchAllResult = await catchAllResult

            var notes: [String] = []
            var didLoadZoneWorkspace = true

            switch resolvedSettingsResult {
            case .success(let settings):
                store.settings = settings
            case .failure(let error):
                didLoadZoneWorkspace = false
                notes.append("Settings: \(error.localizedDescription)")
            }

            switch resolvedDNSResult {
            case .success(let status):
                store.dns = status
            case .failure(let error):
                didLoadZoneWorkspace = false
                store.dns = EmailRoutingDNSStatus(records: [], errors: [])
                notes.append("DNS: \(error.localizedDescription)")
            }

            switch resolvedRulesResult {
            case .success(let rules):
                store.rules = sortedRoutingRules(rules)
            case .failure(let error):
                didLoadZoneWorkspace = false
                store.rules = []
                notes.append("Rules: \(error.localizedDescription)")
            }

            switch resolvedCatchAllResult {
            case .success(let rule):
                store.catchAll = rule
            case .failure(let error):
                didLoadZoneWorkspace = false
                store.catchAll = nil
                notes.append("Catch-all: \(error.localizedDescription)")
            }

            store.statusMessage = notes.isEmpty ? nil : notes.joined(separator: "\n")
            if didLoadZoneWorkspace {
                context.markEmailRoutingLoaded(zoneID: zoneID)
            }

            if let accountID {
                await refreshDestinationAddresses(accountID: accountID, force: force)
            } else {
                store.destinationAddresses = []
                store.destinationAddressesStatusMessage = "Account context is unavailable, so destination addresses cannot be loaded."
            }
        }
    }

    func enableEmailRouting() async {
        guard let zoneID = selectedZoneID else { return }

        await context.withMailLoading {
            do {
                store.settings = try await context.api.enableEmailRouting(zoneID: zoneID)
                context.markEmailRoutingLoaded(zoneID: zoneID)
                context.presentNotice("Email Routing enabled. Review the DNS records before expecting mail flow.")
                await refreshEmailRoutingWorkspace(force: true)
            } catch {
                context.presentError(error)
            }
        }
    }

    func addEmailRoutingDestinationAddress(_ email: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            context.presentAPIError("Enter a valid destination email address.")
            return
        }

        guard let accountID = resolvedAccountID else {
            context.presentAPIError("This token cannot access account-level destination addresses.")
            return
        }

        await context.withMailLoading {
            do {
                let address = try await context.api.createEmailRoutingDestinationAddress(
                    accountID: accountID,
                    email: normalizedEmail
                )
                store.destinationAddresses.append(address)
                store.destinationAddresses = sortedDestinationAddresses(store.destinationAddresses)
                context.markEmailDestinationAddressesLoaded(accountID: accountID)
                store.destinationAddressesStatusMessage = "A verification email was sent. Confirm it before using this destination in a rule."
                context.presentNotice("Destination address created. Check your inbox to verify it.")
            } catch {
                context.presentError(error)
            }
        }
    }

    func updateEmailRoutingCatchAll(destination: String) async {
        let normalizedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedDestination.isEmpty == false else {
            context.presentAPIError("Select a verified destination address first.")
            return
        }

        guard let zoneID = selectedZoneID else { return }

        await context.withMailLoading {
            do {
                store.catchAll = try await context.api.updateEmailRoutingCatchAll(
                    zoneID: zoneID,
                    destination: normalizedDestination
                )
                context.presentNotice("Catch-all updated.")
                await refreshEmailRoutingWorkspace(force: true)
            } catch {
                context.presentError(error)
            }
        }
    }

    private func refreshDestinationAddresses(accountID: String, force: Bool = false) async {
        guard force || context.isEmailDestinationAddressesLoaded(for: accountID) == false else { return }

        do {
            let addresses = try await context.api.listEmailRoutingDestinationAddresses(accountID: accountID)
            store.destinationAddresses = sortedDestinationAddresses(addresses)
            store.destinationAddressesStatusMessage = addresses.isEmpty ? "No destination addresses found." : nil
            context.markEmailDestinationAddressesLoaded(accountID: accountID)
        } catch {
            store.destinationAddresses = []
            store.destinationAddressesStatusMessage = error.localizedDescription
        }
    }

    private func sortedRoutingRules(_ rules: [EmailRoutingRule]) -> [EmailRoutingRule] {
        rules.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return (lhs.priority ?? .max) < (rhs.priority ?? .max)
        }
    }

    private func sortedDestinationAddresses(
        _ addresses: [EmailRoutingDestinationAddress]
    ) -> [EmailRoutingDestinationAddress] {
        addresses.sorted {
            if $0.isVerified == $1.isVerified {
                return $0.email.localizedCaseInsensitiveCompare($1.email) == .orderedAscending
            }
            return $0.isVerified && $1.isVerified == false
        }
    }
}
