import SwiftUI

struct SupportCFPanelView: View {
    private let supportURL = URL(string: "https://afdian.com/a/ResistanceTo")!
    private let githubURL = URL(string: "https://github.com/resistanceto/CFPanel")!
    private let websiteURL = URL(string: "https://cfpanel.zhaohe.org")!

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let resolvedVersion = version?.isEmpty == false ? version ?? "1.0" : "1.0"

        guard let build, build.isEmpty == false else {
            return resolvedVersion
        }
        return "\(resolvedVersion) (\(build))"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "org.zhaohe.CFPanel"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("CFPanel", systemImage: "cloud.fill")
                        .font(.title3.weight(.semibold))

                    Text("A focused third-party Cloudflare client for day-to-day infrastructure work using Cloudflare OAuth, scoped API tokens, and Cloudflare's public APIs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Sponsor CFPanel") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If CFPanel is part of your workflow, sponsorship helps keep it current, reliable, and free for everyone.")
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Text("Support is optional. The goal is sustainable maintenance, not paywalls or feature unlocks.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10, alignment: .leading),
                            GridItem(.flexible(), spacing: 10, alignment: .leading)
                        ],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        SupportChip(title: "Maintenance")
                        SupportChip(title: "App Store Costs")
                        SupportChip(title: "Device Testing")
                        SupportChip(title: "API Compatibility")
                        SupportChip(title: "UI Polish")
                    }

                    Link(destination: supportURL) {
                        SponsorCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            Section("Ways to Help") {
                Link(destination: githubURL) {
                    SupportLinkRow(
                        title: "View on GitHub",
                        detail: "Track releases, report issues, and follow development."
                    )
                }
                .buttonStyle(.plain)

                Link(destination: websiteURL) {
                    SupportLinkRow(
                        title: "Project Website",
                        detail: "Visit the homepage for policy and project information."
                    )
                }
                .buttonStyle(.plain)

                Text("You can also help by sharing CFPanel, filing useful feedback, starring the project, or leaving an App Store review.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Notice") {
                Text("CFPanel is an independent third-party client built for the Cloudflare ecosystem using Cloudflare's public APIs. Cloudflare names and product marks belong to Cloudflare, Inc.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("CFPanel exists in part because Cloudflare has made powerful infrastructure tools accessible to a much wider range of developers and teams.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Version") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("About & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SponsorCard: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("Sponsor on Afdian")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.46, blue: 0.15),
                    Color(red: 0.82, green: 0.27, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "heart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(14)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
    }
}

private struct SupportChip: View {
    let title: LocalizedStringResource

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.orange.opacity(0.18))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SupportLinkRow: View {
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
