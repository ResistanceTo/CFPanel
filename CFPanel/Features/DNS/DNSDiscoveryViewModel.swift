import Foundation
import Observation

@MainActor
@Observable
final class DNSDiscoveryViewModel {
    @ObservationIgnored
    private let recordsViewModel: DNSRecordsViewModel
    @ObservationIgnored
    private let context: DNSWorkspaceContext

    init(recordsViewModel: DNSRecordsViewModel, context: DNSWorkspaceContext) {
        self.recordsViewModel = recordsViewModel
        self.context = context
    }

    var selectedZoneID: String? {
        context.selectedZoneID
    }

    func loadScannedRecords() async throws -> [DNSRecord] {
        let zoneID = try context.requireSelectedZoneID("Select a zone before reviewing discovered DNS records.")
        return try await context.api.listScannedDNSRecords(zoneID: zoneID)
    }

    func triggerScan() async throws {
        let zoneID = try context.requireSelectedZoneID("Select a zone before starting DNS discovery.")
        try await context.api.triggerDNSScan(zoneID: zoneID)
    }

    func reviewScannedRecords(accepts: [DNSRecord], rejects: [DNSRecord]) async throws {
        let zoneID = try context.requireSelectedZoneID("Select a zone before reviewing discovered DNS records.")

        let acceptPayload = accepts.compactMap(\.scanReviewAcceptPayload)
        let rejectIDs = rejects.map(\.id)

        guard acceptPayload.isEmpty == false || rejectIDs.isEmpty == false else {
            return
        }

        _ = try await context.api.reviewScannedDNSRecords(
            zoneID: zoneID,
            accepts: acceptPayload,
            rejects: rejectIDs
        )

        if acceptPayload.isEmpty == false {
            try await recordsViewModel.refresh()
        }
    }
}
