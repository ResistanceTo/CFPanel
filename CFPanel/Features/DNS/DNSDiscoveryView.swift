import SwiftUI

struct DNSScanReviewView: View {
    @Environment(DNSDiscoveryViewModel.self) private var dnsDiscoveryViewModel

    @State private var records: [DNSRecord] = []
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var rawRecord: DNSRecord?

    var body: some View {
        List {
            Section("Discovery") {
                Text(
                    "Use Cloudflare DNS scan review to inspect discovered records before adding them to the zone."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button("Start New Scan") {
                    Task {
                        await triggerScan()
                    }
                }
                .disabled(isSubmitting || dnsDiscoveryViewModel.selectedZoneID == nil)

                Button("Refresh Review Queue") {
                    Task {
                        await loadRecords()
                    }
                }
                .disabled(isLoading || dnsDiscoveryViewModel.selectedZoneID == nil)

                if let statusMessage {
                    Label(statusMessage, systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.blue)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            if isLoading && records.isEmpty {
                Section("Pending Records") {
                    ProgressView("Loading Review Queue")
                }
            } else if records.isEmpty {
                Section("Pending Records") {
                    Text("No discovered DNS records are waiting for review.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Pending Records") {
                    ForEach(records) { record in
                        DNSScannedRecordRow(
                            record: record,
                            isSubmitting: isSubmitting,
                            onAccept: {
                                Task {
                                    await review(accepts: [record], rejects: [])
                                }
                            },
                            onReject: {
                                Task {
                                    await review(accepts: [], rejects: [record])
                                }
                            },
                            onViewRaw: {
                                rawRecord = record
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("DNS Discovery")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRecords()
        }
        .refreshable {
            await loadRecords()
        }
        .sheet(item: $rawRecord) { record in
            DNSRecordPayloadView(record: record)
        }
    }

    private func loadRecords() async {
        isLoading = true
        defer { isLoading = false }

        do {
            records = try await dnsDiscoveryViewModel.loadScannedRecords()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func triggerScan() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await dnsDiscoveryViewModel.triggerScan()
            statusMessage = "Scan started. Refresh review queue in a moment."
            errorMessage = nil
            await loadRecords()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func review(accepts: [DNSRecord], rejects: [DNSRecord]) async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await dnsDiscoveryViewModel.reviewScannedRecords(accepts: accepts, rejects: rejects)
            statusMessage = accepts.isEmpty == false ? "Record accepted." : "Record rejected."
            errorMessage = nil
            await loadRecords()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DNSScannedRecordRow: View {
    let record: DNSRecord
    let isSubmitting: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    let onViewRaw: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(record.type)
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(record.name)
                        .font(.subheadline.weight(.semibold))
                    Text(record.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if record.attentionReasons.isEmpty == false {
                Text(record.attentionReasons.joined(separator: "  ·  "))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                Button("Accept") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)

                Button("Reject", role: .destructive) {
                    onReject()
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)

                Button("Raw JSON") {
                    onViewRaw()
                }
                .buttonStyle(.borderless)
                .disabled(isSubmitting)
            }
        }
        .padding(.vertical, 6)
    }
}
