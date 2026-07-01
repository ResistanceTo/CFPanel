import SwiftUI

struct DataServicesAccountContextSection: View {
    let accountID: String?

    var body: some View {
        Section("Account Context") {
            if let accountID {
                LabeledContent {
                    Text(accountID)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("Account ID")
                }
            } else {
                ContentUnavailableView(
                    "No Account Context",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Open a site first so CFPanel can resolve account-level resources for the active token.")
                )
            }
        }
    }
}

struct DataServiceProductLink: View {
    let product: AccountDataProduct
    let subtitle: LocalizedStringResource

    var body: some View {
        NavigationLink(value: product) {
            CompactNavigationRow(
                title: product.title,
                subtitle: subtitle,
                systemImage: product.systemImage
            )
        }
    }
}

struct DataServiceIntroSection: View {
    let text: LocalizedStringResource

    var body: some View {
        Section {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct DataServiceStatusSection: View {
    let message: String

    var body: some View {
        Section("Status") {
            Text(message)
                .foregroundStyle(.secondary)
        }
    }
}

struct DataServiceMetadataBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }
}

struct KVNamespaceCatalogRow: View {
    let namespace: KVNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Text(namespace.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                DataServiceMetadataBadge(
                    title: namespace.supportsURLEncoding == true ? "Encoded" : "Standard",
                    systemImage: namespace.supportsURLEncoding == true ? "checkmark.seal" : "doc.plaintext",
                    tint: namespace.supportsURLEncoding == true ? .green : .blue
                )
            }

            Text(namespace.id.middleEllipsizedToken)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
    }
}

struct R2BucketCatalogRow: View {
    let bucket: R2Bucket

    var body: some View {
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

                if let jurisdiction = bucket.jurisdictionTitle {
                    DataServiceMetadataBadge(title: jurisdiction, systemImage: "globe", tint: .green)
                }
            }

            if let creationDate = bucket.creationDate {
                Text("Created \(creationDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct D1DatabaseCatalogRow: View {
    let database: D1Database

    var body: some View {
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

                if let tableCount = database.numTables {
                    DataServiceMetadataBadge(
                        title: "\(tableCount) tables",
                        systemImage: "tablecells",
                        tint: .blue
                    )
                }
            }

            if let fileSize = database.fileSize {
                Text(fileSize.bytesFormatted)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct QueueCatalogRow: View {
    let queue: QueueSummary

    var body: some View {
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

                DataServiceMetadataBadge(
                    title: queue.delayTitle,
                    systemImage: queue.delayTitle == "None" ? "clock.badge.checkmark" : "clock.badge.exclamationmark",
                    tint: .orange
                )
            }

            Text("Retention \(queue.retentionTitle)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

struct VectorizeIndexCatalogRow: View {
    let index: VectorizeIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(index.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text(index.configSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let modifiedOn = index.modifiedOn {
                Text("Updated \(modifiedOn.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HyperdriveConfigCatalogRow: View {
    let config: HyperdriveConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(config.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text(config.originSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(config.cachingSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
