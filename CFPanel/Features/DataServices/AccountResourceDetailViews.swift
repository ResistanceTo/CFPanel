import SwiftUI

struct R2BucketDetailView: View {
    @Environment(R2ViewModel.self) private var r2ViewModel
    let bucket: R2Bucket

    @State private var detail: R2BucketDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Bucket") {
                LabeledContent("Name", value: bucket.name)
                LabeledContent("Location", value: detail?.locationTitle ?? bucket.locationTitle)
                LabeledContent("Storage Class", value: detail?.storageClassTitle ?? bucket.storageClassTitle)
                if let jurisdiction = detail?.jurisdictionTitle ?? bucket.jurisdictionTitle {
                    LabeledContent("Jurisdiction", value: jurisdiction)
                }
                if let createdOn = detail?.creationDate ?? bucket.creationDate {
                    LabeledContent("Created", value: createdOn.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Protection") {
                if let lockEnabled = detail?.lockEnabled {
                    LabeledContent("Object Lock", value: lockEnabled ? "Enabled" : "Disabled")
                } else if isLoading {
                    ProgressView("Loading Bucket Details")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No additional protection metadata returned.")
                        .foregroundStyle(.secondary)
                }
            }

            if let rawValue = detail?.rawValue {
                Section("Raw JSON") {
                    Text(rawValue.prettyPrintedString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(bucket.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: bucket.id) {
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
            detail = try await r2ViewModel.loadR2BucketDetail(bucketName: bucket.name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct D1DatabaseDetailView: View {
    @Environment(D1ViewModel.self) private var d1ViewModel
    let database: D1Database

    @State private var detail: D1DatabaseDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Database") {
                LabeledContent("Name", value: database.name)
                LabeledContent {
                    Text(database.uuid)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("ID")
                }
                LabeledContent("Version", value: detail?.versionTitle ?? database.versionTitle)
                LabeledContent("Region", value: detail?.regionTitle ?? database.regionTitle)
                if let createdAt = detail?.createdAt ?? database.createdAt {
                    LabeledContent("Created", value: createdAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Storage") {
                if let numTables = detail?.numTables ?? database.numTables {
                    LabeledContent("Tables", value: numTables.formatted())
                }
                if let fileSize = detail?.fileSize ?? database.fileSize {
                    LabeledContent("Size", value: fileSize.bytesFormatted)
                }
                if detail == nil, isLoading {
                    ProgressView("Loading Database Details")
                } else if let errorMessage, detail == nil {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else if (detail?.numTables ?? database.numTables) == nil,
                          (detail?.fileSize ?? database.fileSize) == nil
                {
                    Text("No storage metrics returned.")
                        .foregroundStyle(.secondary)
                }
            }

            if let rawValue = detail?.rawValue {
                Section("Raw JSON") {
                    Text(rawValue.prettyPrintedString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(database.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: database.id) {
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
            detail = try await d1ViewModel.loadD1DatabaseDetail(databaseID: database.uuid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct QueueDetailView: View {
    @Environment(QueuesViewModel.self) private var queuesViewModel
    let queue: QueueSummary

    @State private var detail: QueueDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Queue") {
                LabeledContent("Name", value: queue.queueName)
                LabeledContent {
                    Text(queue.queueID)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("ID")
                }
                LabeledContent("Delivery Delay", value: detail?.delayTitle ?? queue.delayTitle)
                LabeledContent("Retention", value: detail?.retentionTitle ?? queue.retentionTitle)
                if let createdOn = detail?.createdOn ?? queue.createdOn {
                    LabeledContent("Created", value: createdOn.formatted(date: .abbreviated, time: .shortened))
                }
                if let modifiedOn = detail?.modifiedOn ?? queue.modifiedOn {
                    LabeledContent("Updated", value: modifiedOn.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Consumers") {
                let consumers = detail?.consumers ?? queue.consumers
                if consumers.isEmpty {
                    if isLoading && detail == nil {
                        ProgressView("Loading Consumers")
                    } else {
                        Text("No consumers returned.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(consumers) { consumer in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(consumer.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(consumer.typeTitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                if let maxBatchSize = consumer.maxBatchSize {
                                    Text("\(maxBatchSize) batch")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                }
                            }

                            let details = [
                                consumer.environment,
                                consumer.maxBatchTimeout.map { "\($0)s timeout" },
                                consumer.maxRetries.map { "\($0) retries" },
                                consumer.deadLetterQueue.map { "DLQ \($0)" }
                            ]
                                .compactMap { $0 }

                            if details.isEmpty == false {
                                Text(details.joined(separator: "  ·  "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Producers") {
                let producers = detail?.producers ?? queue.producers
                if producers.isEmpty {
                    if isLoading && detail == nil {
                        ProgressView("Loading Producers")
                    } else {
                        Text("No producers returned.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(producers) { producer in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(producer.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            let details = [producer.script, producer.environment]
                                .compactMap { $0 }

                            if details.isEmpty == false {
                                Text(details.joined(separator: "  ·  "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
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

            if let rawValue = detail?.rawValue {
                Section("Raw JSON") {
                    Text(rawValue.prettyPrintedString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(queue.queueName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: queue.id) {
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
            detail = try await queuesViewModel.loadQueueDetail(queueID: queue.queueID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
