import Foundation
import Observation

@MainActor
@Observable
final class EmailSendingStore {
    var subdomains: [EmailSendingSubdomain] = []
    var statusMessage: String?
    var isUnavailable = false

    func resetZoneScopedState() {
        subdomains = []
        statusMessage = nil
        isUnavailable = false
    }
}
