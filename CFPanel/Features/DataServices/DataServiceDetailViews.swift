import SwiftUI

struct VectorizeIndexDetailView: View {
    @Environment(VectorizeViewModel.self) private var vectorizeViewModel
    let index: VectorizeIndex

    @State private var detail: VectorizeIndex?
    @State private var metadataIndexes: [VectorizeMetadataIndex] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Index") {
                LabeledContent("Name", value: detail?.name ?? index.name)
                if let description = detail?.description ?? index.description,
                   description.isEmpty == false
                {
                    LabeledContent {
                        Text(description)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(3)
                    } label: {
                        Text("Description")
                    }
                }
                if let dimensions = detail?.dimensions ?? index.dimensions {
                    LabeledContent("Dimensions", value: dimensions.formatted())
                }
                LabeledContent("Metric", value: detail?.metricTitle ?? index.metricTitle)
                if let preset = detail?.preset ?? index.preset, preset.isEmpty == false {
                    LabeledContent("Preset", value: preset)
                }
                if let createdOn = detail?.createdOn ?? index.createdOn {
                    LabeledContent("Created", value: createdOn.formatted(date: .abbreviated, time: .shortened))
                }
                if let modifiedOn = detail?.modifiedOn ?? index.modifiedOn {
                    LabeledContent("Updated", value: modifiedOn.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Metadata Indexes") {
                if isLoading && metadataIndexes.isEmpty {
                    ProgressView("Loading Metadata Indexes")
                } else if metadataIndexes.isEmpty {
                    Text("No metadata indexes returned.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(metadataIndexes) { metadataIndex in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                Text(metadataIndex.propertyTitle)
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Text(metadataIndex.typeTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }

                            Text(metadataIndex.rawValue.prettyPrintedString)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let errorMessage {
                Section("Status") {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Raw JSON") {
                Text((detail ?? index).rawValue.prettyPrintedString)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(index.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: index.id) {
            await loadDetail()
        }
        .refreshable {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let resolvedDetail = vectorizeViewModel.loadVectorizeIndexDetail(indexName: index.name)
            async let resolvedMetadata = vectorizeViewModel.loadVectorizeMetadataIndexes(indexName: index.name)
            detail = try await resolvedDetail
            metadataIndexes = try await resolvedMetadata
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HyperdriveConfigDetailView: View {
    @Environment(HyperdriveViewModel.self) private var hyperdriveViewModel
    let config: HyperdriveConfig

    @State private var detail: HyperdriveConfig?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Configuration") {
                LabeledContent("Name", value: detail?.name ?? config.name)
                LabeledContent {
                    Text(config.id)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("ID")
                }
                LabeledContent {
                    Text((detail ?? config).originSummary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                } label: {
                    Text("Origin")
                }
                LabeledContent {
                    Text((detail ?? config).cachingSummary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                } label: {
                    Text("Caching")
                }
                if let limit = detail?.originConnectionLimit ?? config.originConnectionLimit {
                    LabeledContent("Origin Connection Limit", value: limit.formatted())
                }
                if let createdOn = detail?.createdOn ?? config.createdOn {
                    LabeledContent("Created", value: createdOn.formatted(date: .abbreviated, time: .shortened))
                }
                if let modifiedOn = detail?.modifiedOn ?? config.modifiedOn {
                    LabeledContent("Updated", value: modifiedOn.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Origin") {
                if let host = (detail ?? config).host {
                    LabeledContent {
                        Text(host)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.middle)
                    } label: {
                        Text("Host")
                    }
                }
                if let port = (detail ?? config).port {
                    LabeledContent("Port", value: port.formatted())
                }
                if let database = (detail ?? config).database {
                    LabeledContent {
                        Text(database)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.middle)
                    } label: {
                        Text("Database")
                    }
                }
                if let user = (detail ?? config).user {
                    LabeledContent {
                        Text(user)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.middle)
                    } label: {
                        Text("User")
                    }
                }
                if let scheme = (detail ?? config).scheme {
                    LabeledContent("Scheme", value: scheme)
                }
                LabeledContent(
                    "Access Protected",
                    value: (detail ?? config).usesAccessProtectedOrigin ? "Yes" : "No"
                )
            }

            Section("Security") {
                if let mtls = (detail ?? config).mTLS {
                    Text(mtls.prettyPrintedString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                } else if isLoading {
                    ProgressView("Loading Security Details")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No mTLS configuration returned.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Raw JSON") {
                Text((detail ?? config).rawValue.prettyPrintedString)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(config.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: config.id) {
            await loadDetail()
        }
        .refreshable {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await hyperdriveViewModel.loadHyperdriveConfigDetail(configID: config.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
