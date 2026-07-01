import SwiftUI

struct R2StatusCard: View {
    let buckets: [R2Bucket]
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("R2")
                .font(.headline)

            if isRefreshing && buckets.isEmpty {
                ProgressView("Loading R2")
            } else if buckets.isEmpty {
                Text(message ?? "No R2 buckets found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let jurisdictions = Set(buckets.compactMap(\.jurisdiction).filter { $0.isEmpty == false })
                let locations = Set(buckets.compactMap(\.location).filter { $0.isEmpty == false })

                HStack(spacing: 12) {
                    StatusPill(title: "Buckets", value: buckets.count.formatted())
                    StatusPill(title: "Regions", value: locations.count.formatted())
                    StatusPill(title: "Jurisdictions", value: jurisdictions.count.formatted())
                }

                ForEach(buckets.prefix(3)) { bucket in
                    NavigationLink {
                        R2BucketDetailView(bucket: bucket)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(bucket.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text([bucket.locationTitle, bucket.storageClassTitle].joined(separator: "  ·  "))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: bucket.jurisdictionTitle ?? "Global",
                                    tint: bucket.jurisdictionTitle == nil ? .blue : .green
                                )
                            }

                            if let creationDate = bucket.creationDate {
                                Text("Created \(creationDate.formatted(.relative(presentation: .named)))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct D1StatusCard: View {
    let databases: [D1Database]
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("D1")
                .font(.headline)

            if isRefreshing && databases.isEmpty {
                ProgressView("Loading D1")
            } else if databases.isEmpty {
                Text(message ?? "No D1 databases found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let totalTables = databases.reduce(0) { $0 + ($1.numTables ?? 0) }
                let totalBytes = databases.reduce(Int64(0)) { $0 + ($1.fileSize ?? 0) }

                HStack(spacing: 12) {
                    StatusPill(title: "Databases", value: databases.count.formatted())
                    StatusPill(title: "Tables", value: totalTables.formatted())
                    StatusPill(title: "Storage", value: totalBytes.bytesFormatted)
                }

                ForEach(databases.prefix(3)) { database in
                    NavigationLink {
                        D1DatabaseDetailView(database: database)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(database.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(database.regionTitle)  ·  \(database.versionTitle)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: database.numTables.map { "\($0) tables" } ?? "Tables n/a",
                                    tint: (database.numTables ?? 0) > 0 ? .green : .orange
                                )
                            }

                            if let fileSize = database.fileSize {
                                Text(fileSize.bytesFormatted)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct QueuesStatusCard: View {
    let queues: [QueueSummary]
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Queues")
                .font(.headline)

            if isRefreshing && queues.isEmpty {
                ProgressView("Loading Queues")
            } else if queues.isEmpty {
                Text(message ?? "No Queues found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let totalConsumers = queues.reduce(0) { $0 + $1.consumerCount }
                let totalProducers = queues.reduce(0) { $0 + $1.producerCount }

                HStack(spacing: 12) {
                    StatusPill(title: "Queues", value: queues.count.formatted())
                    StatusPill(title: "Consumers", value: totalConsumers.formatted())
                    StatusPill(title: "Producers", value: totalProducers.formatted())
                }

                ForEach(queues.prefix(3)) { queue in
                    NavigationLink {
                        QueueDetailView(queue: queue)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(queue.queueName)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(queue.consumerCount) consumers  ·  \(queue.producerCount) producers")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: queue.delayTitle,
                                    tint: queue.deliveryDelay == nil || queue.deliveryDelay == 0 ? .green : .orange
                                )
                            }

                            Text("Retention \(queue.retentionTitle)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct KVStatusCard: View {
    let namespaces: [KVNamespace]
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KV")
                .font(.headline)

            if isRefreshing && namespaces.isEmpty {
                ProgressView("Loading KV")
            } else if namespaces.isEmpty {
                Text(message ?? "No KV namespaces found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let urlEncodingCount = namespaces.filter { $0.supportsURLEncoding == true }.count

                HStack(spacing: 12) {
                    StatusPill(title: "Namespaces", value: namespaces.count.formatted())
                    StatusPill(title: "URL Encoded", value: urlEncodingCount.formatted())
                    StatusPill(title: "Standard", value: (namespaces.count - urlEncodingCount).formatted())
                }

                ForEach(namespaces.prefix(3)) { namespace in
                    NavigationLink {
                        KVNamespaceDetailView(namespace: namespace)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(namespace.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(namespace.id.middleEllipsizedToken)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: namespace.supportsURLEncoding == true ? "Encoded" : "Standard",
                                    tint: namespace.supportsURLEncoding == true ? .green : .blue
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct VectorizeStatusCard: View {
    let indexes: [VectorizeIndex]
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vectorize")
                .font(.headline)

            if isRefreshing && indexes.isEmpty {
                ProgressView("Loading Vectorize")
            } else if indexes.isEmpty {
                Text(message ?? "No Vectorize indexes found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let configuredDimensions = indexes.compactMap(\.dimensions)
                let maxDimensions = configuredDimensions.max() ?? 0
                let metricKinds = Set(indexes.compactMap(\.metric).filter { $0.isEmpty == false })

                HStack(spacing: 12) {
                    StatusPill(title: "Indexes", value: indexes.count.formatted())
                    StatusPill(title: "Max Dims", value: maxDimensions == 0 ? "n/a" : maxDimensions.formatted())
                    StatusPill(title: "Metrics", value: metricKinds.count.formatted())
                }

                ForEach(indexes.prefix(3)) { index in
                    NavigationLink {
                        VectorizeIndexDetailView(index: index)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(index.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(index.configSummary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: index.metricTitle,
                                    tint: .blue
                                )
                            }

                            if let description = index.description, description.isEmpty == false {
                                Text(description)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct HyperdriveStatusCard: View {
    let configs: [HyperdriveConfig]
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hyperdrive")
                .font(.headline)

            if isRefreshing && configs.isEmpty {
                ProgressView("Loading Hyperdrive")
            } else if configs.isEmpty {
                Text(message ?? "No Hyperdrive configurations found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let cachedCount = configs.filter(\.cachingEnabled).count
                let protectedOriginCount = configs.filter(\.usesAccessProtectedOrigin).count

                HStack(spacing: 12) {
                    StatusPill(title: "Configs", value: configs.count.formatted())
                    StatusPill(title: "Cached", value: cachedCount.formatted())
                    StatusPill(title: "Protected", value: protectedOriginCount.formatted())
                }

                ForEach(configs.prefix(3)) { config in
                    NavigationLink {
                        HyperdriveConfigDetailView(config: config)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(config.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(config.originSummary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: config.cachingEnabled ? "Cached" : "Direct",
                                    tint: config.cachingEnabled ? .green : .orange
                                )
                            }

                            Text(config.cachingSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}
