import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DNSRecordRow: View {
    let record: DNSRecord

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(record.type)
                .font(.caption.bold())
                .foregroundStyle(.blue)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(record.name)
                        .foregroundStyle(.primary)

                    if record.isDNSOnlyWebRecord {
                        rowBadge("DNS Only", tint: .orange)
                    }

                    if record.isWildcard {
                        rowBadge("Wildcard", tint: .blue)
                    }
                }

                Text(record.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let comment = record.comment, comment.isEmpty == false {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if record.supportedType == nil {
                    Text("Raw JSON fallback")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private func rowBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct DNSRiskSummaryCard: View {
    let summary: DNSRiskSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if summary.totalAttentionItems == 0 {
                Label("No DNS records need attention right now.", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                Text("Review these records before making broader zone changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    riskPill(title: "DNS-only Web", value: summary.dnsOnlyWebRecords.formatted(), tint: .orange)
                    riskPill(title: "Wildcard", value: summary.wildcardRecords.formatted(), tint: .blue)
                    riskPill(title: "Unsupported", value: summary.unsupportedRecords.formatted(), tint: .red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private func riskPill(title: LocalizedStringResource, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: 16))
    }
}

struct DNSRecordDetailView: View {
    @Environment(DNSRecordsViewModel.self) private var dnsRecordsViewModel
    @Environment(\.dismiss) private var dismiss

    let record: DNSRecord
    let showRawJSON: () -> Void
    let editRecord: () -> Void

    @State private var copiedMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Record") {
                    LabeledContent("Name", value: record.name)
                    LabeledContent("Type", value: record.type)
                    LabeledContent("Value", value: record.summary)
                    LabeledContent("TTL", value: record.ttlTitle)
                    if let priority = record.priority {
                        LabeledContent("Priority", value: priority.formatted())
                    }
                    LabeledContent("Exposure", value: record.proxyStatusTitle)
                    if let modifiedOn = record.modifiedOn {
                        LabeledContent("Updated", value: modifiedOn.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if let comment = record.comment, comment.isEmpty == false {
                    Section("Comment") {
                        Text(comment)
                            .font(.subheadline)
                    }
                }

                if record.attentionReasons.isEmpty == false {
                    Section("Attention") {
                        ForEach(record.attentionReasons, id: \.self) { reason in
                            Label(reason, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Quick Actions") {
                    Button("Copy Record Name") {
                        copy(record.name, message: "Record name copied.")
                    }
                    Button("Copy Record Value") {
                        copy(record.summary, message: "Record value copied.")
                    }
                    Button("Filter Same Name") {
                        dnsRecordsViewModel.searchText = record.name
                        dismiss()
                    }
                    Button("Filter Same Type") {
                        dnsRecordsViewModel.typeFilter = typeFilter(for: record)
                        dismiss()
                    }
                    Button("Show Attention Only") {
                        dnsRecordsViewModel.riskFilter = .attentionOnly
                        dismiss()
                    }
                }

                Section("More") {
                    Button(record.supportedType == nil ? "Open Raw JSON" : "Edit Record") {
                        dismiss()
                        editRecord()
                    }

                    Button("View Raw JSON") {
                        dismiss()
                        showRawJSON()
                    }
                }

                if let copiedMessage {
                    Section {
                        Label(copiedMessage, systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle(record.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func copy(_ value: String, message: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = value
        copiedMessage = message
#else
        copiedMessage = "Clipboard is unavailable in this build environment."
#endif
    }

    private func typeFilter(for record: DNSRecord) -> DNSRecordTypeFilter {
        switch record.normalizedType {
        case "A":
            .a
        case "AAAA":
            .aaaa
        case "CNAME":
            .cname
        case "MX":
            .mx
        case "TXT":
            .txt
        default:
            .other
        }
    }
}

struct DNSRecordEditorView: View {
    @Environment(DNSRecordsViewModel.self) private var dnsRecordsViewModel
    @State private var draft: DNSRecordDraft

    init(draft: DNSRecordDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $draft.type) {
                    ForEach(SupportedDNSRecordType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }

                TextField("Name", text: $draft.name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if draft.type.usesStructuredData {
                    Section("Record Data") {
                        Text(draft.type.guidance)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ForEach(draft.type.dataFields) { field in
                            TextField(
                                field.placeholder,
                                text: Binding(
                                    get: { draft.data[field.key] ?? "" },
                                    set: { draft.data[field.key] = $0 }
                                ),
                                prompt: Text(field.title)
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(field.valueKind == .integer ? .numberPad : .default)
                        }
                    }
                } else {
                    TextField(draft.type.contentTitle, text: $draft.content, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(3 ... 6)

                    Text(draft.type.guidance)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker("TTL", selection: $draft.ttl) {
                    ForEach(TTLSelection.allCases) { ttl in
                        Text(ttl.title).tag(ttl.rawValue)
                    }
                }

                if draft.type.supportsProxied {
                    Toggle("Proxied", isOn: $draft.proxied)
                }

                if draft.type.supportsPriority {
                    TextField(
                        "Priority",
                        value: Binding(
                            get: { draft.priority ?? 10 },
                            set: { draft.priority = $0 }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                }

                TextField("Comment", text: $draft.comment)

                if let validationError = draft.validationError {
                    Section {
                        Label(validationError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(draft.recordID == nil ? "New DNS Record" : "Edit DNS Record")
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dnsRecordsViewModel.editor = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await dnsRecordsViewModel.saveRecord(draft)
                        }
                    }
                    .disabled(draft.validationError != nil)
                }
            }
        }
    }
}

struct DNSRecordPayloadView: View {
    let record: DNSRecord

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(record.rawJSON)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(record.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
