import SwiftUI

struct PagesProjectDetailView: View {
    let project: PagesProject

    var body: some View {
        List {
            projectSection
            currentStatusSection
            menuSection
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var projectSection: some View {
        Section("Project") {
            LabeledContent {
                Text(project.name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
            } label: {
                Text("Name")
            }
            if let subdomain = project.subdomain {
                LabeledContent {
                    Text(subdomain)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("Subdomain")
                }
            }
            if let productionBranch = project.productionBranch {
                LabeledContent {
                    Text(productionBranch)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("Production Branch")
                }
            }
            Text("This page stays lightweight. Open a deeper menu to load deployment history, domains, or destructive actions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    @ViewBuilder
    private var currentStatusSection: some View {
        Section("Current Production Status") {
            if let deployment = project.canonicalDeployment {
                LabeledContent("Status", value: deployment.statusTitle)
                LabeledContent("Environment", value: deployment.environmentTitle)
                if let createdOn = deployment.createdOn {
                    LabeledContent("Created", value: createdOn.formatted(date: .abbreviated, time: .shortened))
                }
                if let modifiedOn = deployment.modifiedOn {
                    LabeledContent("Updated", value: modifiedOn.formatted(date: .abbreviated, time: .shortened))
                }
            } else {
                Text("The catalog did not return a canonical production deployment for this project.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var menuSection: some View {
        Section("Project Menus") {
            NavigationLink(value: PagesProjectRoute(projectID: project.id, destination: .deployments)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deployments")
                    Text("Load production and preview deployment history, logs, retries, rollbacks, and deletion.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            NavigationLink(value: PagesProjectRoute(projectID: project.id, destination: .domains)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Domains")
                    Text("Load attached domains, validation state, and domain-level actions only when you open this page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            NavigationLink(value: PagesProjectRoute(projectID: project.id, destination: .operations)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Operations")
                    Text("Purge build cache or delete the project without loading domain inventory.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
