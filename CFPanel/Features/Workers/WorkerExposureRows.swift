import SwiftUI

struct WorkerExposureContextSection: View {
    let scriptID: String
    let zoneName: String?

    var body: some View {
        Section("Context") {
            LabeledContent("Script", value: scriptID)
            LabeledContent("Zone", value: zoneName ?? "No zone selected")
            Text("This page only loads workers.dev status, zone routes, and custom domains for the current script.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct WorkerExposureNoticeSection: View {
    let title: LocalizedStringResource
    let message: String

    var body: some View {
        Section(title) {
            Text(message)
                .foregroundStyle(.secondary)
        }
    }
}

struct WorkerRouteManagementRow: View {
    let route: WorkerRoute
    let scriptID: String
    let isDangerousModeEnabled: Bool
    let isPerformingAction: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WorkerRouteRow(route: route, scriptID: scriptID)

            Spacer(minLength: 0)

            Button("Edit", action: onEdit)
                .disabled(isPerformingAction)

            if isDangerousModeEnabled {
                Button("Delete", role: .destructive, action: onDelete)
                    .disabled(isPerformingAction)
            }
        }
    }
}

struct WorkerCustomDomainManagementRow: View {
    let domain: WorkerDomain
    let scriptID: String
    let isDangerousModeEnabled: Bool
    let isPerformingAction: Bool
    let onDelete: () -> Void

    private var canDelete: Bool {
        isDangerousModeEnabled && domain.id?.isEmpty == false
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WorkerDomainRow(domain: domain, scriptID: scriptID)

            Spacer(minLength: 0)

            if canDelete {
                Button("Delete", role: .destructive, action: onDelete)
                    .disabled(isPerformingAction)
            } else {
                Label("Read only", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
            }
        }
    }
}
