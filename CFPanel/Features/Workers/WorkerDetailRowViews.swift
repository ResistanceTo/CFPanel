import SwiftUI

struct WorkerOperationalNoteRow: View {
    let note: WorkerOperationalNote

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: noteIcon)
                .foregroundStyle(noteColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(note.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var noteColor: Color {
        switch note.severity {
        case .critical:
            .red
        case .warning:
            .orange
        case .info:
            .blue
        }
    }

    private var noteIcon: String {
        switch note.severity {
        case .critical:
            "exclamationmark.octagon.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .info:
            "info.circle.fill"
        }
    }
}

struct WorkerRouteRow: View {
    let route: WorkerRoute
    let scriptID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.pattern)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(route.script == scriptID ? "Attached to this script" : "Script binding mismatch")
                .font(.caption)
                .foregroundStyle(route.script == scriptID ? Color.secondary : .orange)
                .lineLimit(1)
        }
    }
}

struct WorkerDomainRow: View {
    let domain: WorkerDomain
    let scriptID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(domain.hostname ?? "Unknown Hostname")
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            if let zoneName = domain.zoneName {
                Text(zoneName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let service = domain.service {
                Text(service)
                    .font(.caption)
                    .foregroundStyle(service == scriptID ? Color.secondary : .orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

struct WorkerDeploymentRow: View {
    let deployment: WorkerDeployment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deployment.source?.capitalized ?? "Deployment")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let strategy = deployment.strategy, strategy.isEmpty == false {
                        Text(strategy.replacingOccurrences(of: "_", with: " ").localizedCapitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if let triggeredBy = deployment.triggeredBy, triggeredBy.isEmpty == false {
                    Text(triggeredBy.replacingOccurrences(of: "_", with: " ").localizedCapitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
            }

            Text(deployment.id)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let createdOn = deployment.createdOn {
                Text(createdOn.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let authorEmail = deployment.authorEmail, authorEmail.isEmpty == false {
                Text(authorEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let message = deployment.deploymentMessage, message.isEmpty == false {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if deployment.versions.isEmpty == false {
                ForEach(deployment.versions) { version in
                    HStack(spacing: 12) {
                        Text(version.versionID.middleEllipsizedToken)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(version.percentage, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct WorkerVersionSummaryRow: View {
    let version: WorkerVersion
    let deployment: WorkerDeployment?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(version.versionNumberTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(version.id)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                if let deployment,
                   let deploymentVersion = deployment.versions.first(where: { $0.versionID == version.id })
                {
                    Text(deploymentVersion.percentage, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            if let sourceTitle = version.sourceTitle {
                Text(sourceTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let authorEmail = version.metadata?.authorEmail, authorEmail.isEmpty == false {
                Text(authorEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let deploymentMessage = version.metadata?.deploymentMessage, deploymentMessage.isEmpty == false {
                Text(deploymentMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct WorkerBindingRow: View {
    let binding: WorkerBinding

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Text(binding.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(binding.typeTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }

            if let summary = binding.summary {
                Text(summary)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct WorkerTailConsumerRow: View {
    let consumer: WorkerTailConsumer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(consumer.service ?? "Tail Consumer")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(
                [consumer.environment, consumer.namespace]
                    .compactMap { $0 }
                    .joined(separator: "  ·  ")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct WorkerJSONField: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(8)
        }
        .padding(.vertical, 4)
    }
}
