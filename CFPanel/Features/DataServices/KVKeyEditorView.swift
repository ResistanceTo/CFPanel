import SwiftUI

struct KVKeyEditorView: View {
    @Environment(KVViewModel.self) private var kvViewModel
    @Environment(\.dismiss) private var dismiss

    let namespaceID: String
    let namespaceTitle: String
    let draft: KVKeyDraft
    let onSaved: () -> Void

    @State private var keyName: String
    @State private var value: String
    @State private var metadataText: String
    @State private var expirationMode: KVExpirationMode
    @State private var expirationDate: Date
    @State private var expirationTTLText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        namespaceID: String,
        namespaceTitle: String,
        draft: KVKeyDraft,
        onSaved: @escaping () -> Void
    ) {
        self.namespaceID = namespaceID
        self.namespaceTitle = namespaceTitle
        self.draft = draft
        self.onSaved = onSaved
        _keyName = State(initialValue: draft.keyName)
        _value = State(initialValue: draft.value)
        _metadataText = State(initialValue: draft.metadataText)
        _expirationMode = State(initialValue: draft.expirationMode)
        _expirationDate = State(initialValue: draft.expirationDate)
        _expirationTTLText = State(initialValue: draft.expirationTTLText)
    }

    var body: some View {
        Form {
            Section("Namespace") {
                LabeledContent("Namespace", value: namespaceTitle)
            }

            Section("Key") {
                if draft.isEditingExistingKey {
                    LabeledContent("Key", value: keyName)
                } else {
                    TextField("session:token", text: $keyName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section("Value") {
                TextEditor(text: $value)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
            }

            Section("Metadata") {
                TextEditor(text: $metadataText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
            }

            Section("Expiration") {
                Picker("Mode", selection: $expirationMode) {
                    ForEach(KVExpirationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if expirationMode == .absolute {
                    DatePicker(
                        "Expires At",
                        selection: $expirationDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } else if expirationMode == .ttl {
                    TextField("3600", text: $expirationTTLText)
                        .keyboardType(.numberPad)
                        .font(.system(.body, design: .monospaced))
                }
            }

            if let errorMessage {
                Section("Status") {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(draft.isEditingExistingKey ? "Edit Key" : "New Key")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(draft.isEditingExistingKey ? "Save" : "Create") {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() async {
        let normalizedKey = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedKey.isEmpty == false else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            let metadata = try parseMetadata(metadataText)
            let expirationTTL = expirationMode == .ttl ? Int(expirationTTLText.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
            try KVOperationLimits.validateSingleWrite(
                key: normalizedKey,
                value: value,
                metadata: metadata,
                expirationTTL: expirationTTL
            )
            try await kvViewModel.writeKVValue(
                namespaceID: namespaceID,
                keyName: normalizedKey,
                value: value,
                metadata: metadata,
                expiration: expirationMode == .absolute ? expirationDate : nil,
                expirationTTL: expirationTTL
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseMetadata(_ rawValue: String) throws -> JSONValue? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        guard let data = trimmed.data(using: .utf8) else {
            throw CloudflareAPIError.api("Metadata must be valid UTF-8 JSON.")
        }

        do {
            return try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            throw CloudflareAPIError.api("Metadata must be valid JSON.")
        }
    }
}
