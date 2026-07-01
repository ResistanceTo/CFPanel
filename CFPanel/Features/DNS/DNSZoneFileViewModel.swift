import Foundation
import Observation

@MainActor
@Observable
final class DNSZoneFileViewModel {
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

    var selectedZone: CloudflareZone? {
        context.selectedZone
    }

    func exportRecords() async throws -> String {
        let zoneID = try context.requireSelectedZoneID("Select a zone before exporting DNS records.")
        return try await context.api.exportDNSRecords(zoneID: zoneID)
    }

    func importRecords(fileName: String, fileData: Data, proxied: Bool) async throws -> DNSImportResponse {
        let zoneID = try context.requireSelectedZoneID("Select a zone before importing DNS records.")

        let response = try await context.api.importDNSRecords(
            zoneID: zoneID,
            fileName: fileName,
            fileData: fileData,
            proxied: proxied
        )
        try await recordsViewModel.refresh()
        return response
    }
}
