import SwiftUI

struct PagesEnvironmentSummaryRow: View {
    let summary: PagesEnvironmentSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.subheadline.weight(.semibold))
                    Text(summary.statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                PagesStatusBadge(title: summary.badgeText, tint: pagesBadgeColor(summary))
            }

            HStack(spacing: 12) {
                Text("\(summary.healthyCount) healthy")
                Text("\(summary.failedCount) failed")
                Text("\(summary.inProgressCount) active")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let updatedText = summary.updatedText {
                Text("Updated \(updatedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PagesDeploymentRow: View {
    let deployment: PagesDeployment
    let isPerformingAction: Bool
    let onShowLogs: () -> Void
    let onRetry: () -> Void
    let onRollback: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        deployment: PagesDeployment,
        isPerformingAction: Bool,
        onShowLogs: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onRollback: (() -> Void)?,
        onDelete: (() -> Void)? = nil
    ) {
        self.deployment = deployment
        self.isPerformingAction = isPerformingAction
        self.onShowLogs = onShowLogs
        self.onRetry = onRetry
        self.onRollback = onRollback
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deployment.statusTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(deployment.environmentTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                PagesStatusBadge(title: deploymentBadgeText, tint: pagesBadgeColor(deployment))
            }

            if let url = deployment.url {
                let resolvedURL = url.hasPrefix("http") ? url : "https://\(url)"
                if let destination = URL(string: resolvedURL) {
                    Link(url, destination: destination)
                        .font(.system(.footnote, design: .monospaced))
                }
            }

            if let createdOn = deployment.createdOn {
                Text(createdOn.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button("Logs", action: onShowLogs)
                    .buttonStyle(.borderless)

                Button("Retry", action: onRetry)
                    .buttonStyle(.borderless)
                    .disabled(isPerformingAction)

                if let onRollback {
                    Button("Rollback", action: onRollback)
                        .buttonStyle(.borderless)
                        .disabled(isPerformingAction)
                }

                if let onDelete {
                    Button("Delete", role: .destructive, action: onDelete)
                        .buttonStyle(.borderless)
                        .disabled(isPerformingAction)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private var deploymentBadgeText: String {
        switch deployment.health {
        case .healthy:
            "Healthy"
        case .inProgress:
            "Building"
        case .failed:
            "Failed"
        case .unknown:
            "Unknown"
        }
    }
}

struct PagesOperationalNoteRow: View {
    let note: PagesOperationalNote

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: noteIcon)
                .foregroundStyle(noteColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                Text(note.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

struct PagesDomainRow: View {
    let domain: PagesProjectDomain
    let isPerformingAction: Bool
    let onRetryValidation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(domain.name)
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    Text(domain.statusTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                PagesStatusBadge(
                    title: domain.isActive ? "Active" : (domain.isPending ? "Pending" : (domain.hasError ? "Attention" : "Unknown")),
                    tint: domain.isActive ? .green : (domain.hasError ? .red : .orange)
                )
            }

            if let validationData = domain.validationData {
                Text(validationData.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let txtName = validationData.txtName,
                   let txtValue = validationData.txtValue,
                   txtName.isEmpty == false,
                   txtValue.isEmpty == false
                {
                    Text("\(txtName) = \(txtValue)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let errorMessage = validationData.errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let verificationData = domain.verificationData {
                Text(verificationData.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let errorMessage = verificationData.errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if domain.isActive == false {
                Button("Retry Validation", action: onRetryValidation)
                    .buttonStyle(.borderless)
                    .disabled(isPerformingAction)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PagesStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private func pagesBadgeColor(_ summary: PagesEnvironmentSummary) -> Color {
    switch summary.latestDeployment?.health ?? .unknown {
    case .healthy:
        .green
    case .inProgress:
        .blue
    case .failed:
        .red
    case .unknown:
        summary.deployments.isEmpty ? .orange : .gray
    }
}

private func pagesBadgeColor(_ deployment: PagesDeployment) -> Color {
    switch deployment.health {
    case .healthy:
        .green
    case .inProgress:
        .blue
    case .failed:
        .red
    case .unknown:
        .gray
    }
}
