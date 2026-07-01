import SwiftUI

struct KVNamespaceKeyValueView: View {
    @Environment(KVViewModel.self) private var kvViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false

    let namespaceID: String
    let namespaceTitle: String
    let key: KVNamespaceKey
    let onMutation: () -> Void

    @State private var snapshot: KVValueSnapshot?
    @State private var isLoading = false
    @State private var isPerformingAction = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var editorDraft: KVKeyDraft?

    var body: some View {
        List {
            Section("Key") {
                LabeledContent("Namespace", value: namespaceTitle)
                LabeledContent("Key", value: key.name)
                if let byteCount = snapshot?.byteCount {
                    LabeledContent("Size", value: "\(byteCount) bytes")
                }
                if let contentType = snapshot?.contentType {
                    LabeledContent("Content Type", value: contentType)
                }
                if let expiration = snapshot?.expiration ?? key.expirationDate {
                    LabeledContent("Expires", value: expiration.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Value") {
                if isLoading && snapshot == nil {
                    ProgressView("Loading Value")
                } else if let snapshot {
                    LabeledContent("Preview", value: snapshot.valuePreviewTitle)
                    Text(snapshot.value)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    if snapshot.isValueTruncated {
                        Text("The value is larger than the in-app preview limit. Editing starts from the displayed preview only, so avoid saving unless you intend to replace the stored value.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No value returned.")
                        .foregroundStyle(.secondary)
                }
            }

            if let metadata = snapshot?.metadata {
                Section("Metadata") {
                    Text(metadata.prettyPrintedString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Section("Actions") {
                Button("Edit Value") {
                    editorDraft = KVKeyDraft(
                        existingKeyName: key.name,
                        keyName: key.name,
                        value: snapshot?.value ?? "",
                        metadataText: snapshot?.metadata?.prettyPrintedString ?? "",
                        expirationMode: (snapshot?.expiration ?? key.expirationDate) == nil ? .none : .absolute,
                        expirationDate: snapshot?.expiration ?? key.expirationDate ?? Date(),
                        expirationTTLText: ""
                    )
                }
                .disabled(isPerformingAction || isLoading || snapshot?.isBinary == true || snapshot?.isValueTruncated == true)

                if isAdvancedDangerousModeEnabled {
                    Button("Delete Key", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(isPerformingAction)
                }
            }
        }
        .navigationTitle(key.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: key.id) {
            await loadValue()
        }
        .refreshable {
            await loadValue()
        }
        .countdownConfirmationDialog(
            "Delete \(key.name)?",
            isPresented: $showDeleteConfirmation,
            message: keyDeletionMessage,
            actionTitle: "Delete Key"
        ) {
            Task {
                await deleteKey()
            }
        }
        .sheet(item: $editorDraft) { draft in
            NavigationStack {
                KVKeyEditorView(
                    namespaceID: namespaceID,
                    namespaceTitle: namespaceTitle,
                    draft: draft,
                    onSaved: {
                        Task {
                            await loadValue()
                        }
                        onMutation()
                    }
                )
            }
        }
    }

    private func loadValue() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await kvViewModel.loadKVValue(namespaceID: namespaceID, keyName: key.name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteKey() async {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm deletion of KV key \(key.name)."
            )
            try await kvViewModel.deleteKVValue(namespaceID: namespaceID, keyName: key.name)
            onMutation()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var keyDeletionMessage: String {
        DangerousOperationMessage.destructive(
            resource: "KV key",
            name: key.name,
            scope: namespaceTitle,
            impact: "Cloudflare will remove this key and its value from the namespace. Reads for this key can start failing immediately."
        )
    }
}
