import SwiftUI
import UniformTypeIdentifiers

private func shouldIgnoreCancellation(_ error: Error) -> Bool {
    if error is CancellationError {
        return true
    }

    if let urlError = error as? URLError,
       urlError.code == .cancelled
    {
        return true
    }

    let nsError = error as NSError
    return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
}

struct DNSZoneFileView: View {
    @Environment(DNSZoneFileViewModel.self) private var dnsZoneFileViewModel

    @State private var isImporting = false
    @State private var isLoadingExport = false
    @State private var showImporter = false
    @State private var exportDocument = TextExportDocument(text: "")
    @State private var exportFileName = "zone.txt"
    @State private var showExporter = false
    @State private var forceProxiedImport = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("BIND Tools") {
                Text("Import or export DNS records using Cloudflare's BIND-compatible zone file endpoints.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Toggle("Force Imported Records Proxied", isOn: $forceProxiedImport)

                Button("Export Zone File") {
                    Task {
                        await exportZoneFile()
                    }
                }
                .disabled(isLoadingExport || isImporting || dnsZoneFileViewModel.selectedZoneID == nil)

                Button("Import Zone File") {
                    showImporter = true
                }
                .disabled(isLoadingExport || isImporting || dnsZoneFileViewModel.selectedZoneID == nil)
            }

            Section("Notes") {
                Label("Export returns a BIND-style zone file snapshot for the selected zone.", systemImage: "doc.text")
                Label("Import uploads a zone file to Cloudflare and refreshes DNS records after completion.", systemImage: "square.and.arrow.down")
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Zone File")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await importZoneFile(from: url)
                }
            case .failure(let error):
                guard shouldIgnoreCancellation(error) == false else { return }
                errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                statusMessage = "Zone file export ready."
            case .failure(let error):
                guard shouldIgnoreCancellation(error) == false else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func exportZoneFile() async {
        isLoadingExport = true
        defer { isLoadingExport = false }

        do {
            let text = try await dnsZoneFileViewModel.exportRecords()
            let zoneName = dnsZoneFileViewModel.selectedZone?.name.replacingOccurrences(of: ".", with: "-") ?? "zone"
            exportDocument = TextExportDocument(text: text)
            exportFileName = "\(zoneName)-cloudflare-zone.txt"
            showExporter = true
            errorMessage = nil
        } catch {
            guard shouldIgnoreCancellation(error) == false else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func importZoneFile(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let startedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if startedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let response = try await dnsZoneFileViewModel.importRecords(
                fileName: url.lastPathComponent,
                fileData: data,
                proxied: forceProxiedImport
            )
            let added = response.recsAdded ?? 0
            let parsed = response.totalRecordsParsed ?? 0
            statusMessage = "Imported \(added) records from \(parsed) parsed entries."
            errorMessage = nil
        } catch {
            guard shouldIgnoreCancellation(error) == false else { return }
            errorMessage = error.localizedDescription
        }
    }
}
