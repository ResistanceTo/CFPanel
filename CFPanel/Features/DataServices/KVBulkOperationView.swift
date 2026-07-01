import SwiftUI

struct KVBulkOperationView: View {
    @Environment(KVViewModel.self) private var kvViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false

    let namespaceID: String
    let namespaceTitle: String
    let draft: KVBulkDraft
    let onCompleted: () -> Void

    @State private var payload: String
    @State private var isPerforming = false
    @State private var statusMessage: String?
    @State private var isConfirmingBulkDelete = false

    init(
        namespaceID: String,
        namespaceTitle: String,
        draft: KVBulkDraft,
        onCompleted: @escaping () -> Void
    ) {
        self.namespaceID = namespaceID
        self.namespaceTitle = namespaceTitle
        self.draft = draft
        self.onCompleted = onCompleted
        _payload = State(initialValue: draft.payload)
    }

    var body: some View {
        Form {
            Section("Namespace") {
                LabeledContent("Namespace", value: namespaceTitle)
            }

            Section(draft.mode == .write ? "Bulk Write JSON" : "Keys") {
                TextEditor(text: $payload)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)

                Text(draft.mode.helpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(draft.mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(draft.mode.actionTitle) {
                    if draft.mode == .delete {
                        isConfirmingBulkDelete = true
                    } else {
                        Task {
                            await perform()
                        }
                    }
                }
                .disabled(
                    isPerforming
                        || payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || (draft.mode == .delete && isAdvancedDangerousModeEnabled == false)
                )
            }
        }
        .countdownConfirmationDialog(
            "Bulk delete KV keys?",
            isPresented: $isConfirmingBulkDelete,
            message: isAdvancedDangerousModeEnabled
                ? bulkDeleteConfirmationMessage
                : "Enable Advanced Dangerous Mode in Settings before bulk deleting keys.",
            actionTitle: "Delete Keys"
        ) {
            Task {
                await perform()
            }
        }
    }

    private var bulkDeleteKeyCount: Int {
        payload
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .count
    }

    private var bulkDeleteConfirmationMessage: String {
        let keyCount = bulkDeleteKeyCount
        return DangerousOperationMessage.destructive(
            resource: "KV keys",
            name: "\(keyCount) keys",
            scope: namespaceTitle,
            impact: "Cloudflare will remove every listed key from the namespace. Reads for those keys can start failing immediately."
        )
    }

    private func perform() async {
        isPerforming = true
        defer { isPerforming = false }

        do {
            switch draft.mode {
            case .write:
                let entries = try parseBulkEntries(payload)
                try KVOperationLimits.validateBulkWriteEntries(entries)
                let result = try await kvViewModel.bulkWriteKVValues(namespaceID: namespaceID, entries: entries)
                statusMessage = bulkStatusMessage(prefix: "Bulk write completed", result: result)
            case .delete:
                let keys = payload
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
                guard isAdvancedDangerousModeEnabled else {
                    throw CloudflareAPIError.api("Enable Advanced Dangerous Mode in Settings before bulk deleting keys.")
                }
                try KVOperationLimits.validateBulkDeleteKeys(keys)
                try await DangerousActionAuthorizer.authorize(
                    reason: "Confirm bulk deletion of \(keys.count) KV keys."
                )
                let result = try await kvViewModel.bulkDeleteKVValues(namespaceID: namespaceID, keys: keys)
                statusMessage = bulkStatusMessage(prefix: "Bulk delete completed", result: result)
            }

            onCompleted()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func parseBulkEntries(_ rawValue: String) throws -> [KVBulkWriteEntry] {
        try KVOperationLimits.validateBulkWritePayload(rawValue)

        guard let data = rawValue.data(using: .utf8) else {
            throw CloudflareAPIError.api("Bulk write payload must be valid UTF-8 JSON.")
        }

        do {
            return try JSONDecoder().decode([KVBulkWriteEntry].self, from: data)
        } catch {
            throw CloudflareAPIError.api("Bulk write payload must be a valid JSON array of KV entries.")
        }
    }

    private func bulkStatusMessage(prefix: String, result: KVBulkMutationResult) -> String {
        var parts = [prefix]
        if let successfulKeyCount = result.successfulKeyCount {
            parts.append("\(successfulKeyCount) succeeded")
        }
        if let unsuccessfulKeys = result.unsuccessfulKeys, unsuccessfulKeys.isEmpty == false {
            parts.append("\(unsuccessfulKeys.count) failed")
        }
        return parts.joined(separator: " · ")
    }
}
