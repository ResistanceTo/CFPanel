import Foundation
import Observation

@MainActor
@Observable
final class EmailRoutingStore {
    var settings: EmailRoutingSettings?
    var dns = EmailRoutingDNSStatus(records: [], errors: [])
    var rules: [EmailRoutingRule] = []
    var catchAll: EmailRoutingRule?
    var statusMessage: String?
    var destinationAddresses: [EmailRoutingDestinationAddress] = []
    var destinationAddressesStatusMessage: String?

    func resetZoneScopedState() {
        settings = nil
        dns = EmailRoutingDNSStatus(records: [], errors: [])
        rules = []
        catchAll = nil
        statusMessage = nil
    }

    func resetAccountScopedState(statusMessage: String? = nil) {
        destinationAddresses = []
        destinationAddressesStatusMessage = statusMessage
    }
}
