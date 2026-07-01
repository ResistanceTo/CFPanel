import SwiftUI

enum TokenPermissionGuidance {
    static let minimumRows: [(title: LocalizedStringResource, detail: LocalizedStringResource)] = [
        (
            "Zones and site overview",
            "Zone:Read is the baseline permission for loading zone inventory and site details."
        ),
        (
            "DNS and mail routing",
            "Add DNS:Read/Edit and Email Routing permissions only if you want CFPanel to inspect or mutate those surfaces."
        ),
        (
            "Security, cache, and settings",
            "Add Zone Settings:Read/Edit and Cache Purge for SSL/TLS, security level, HSTS, cache controls, and incident response."
        ),
        (
            "Account products",
            "Pages, Workers, R2, D1, KV, Queues, Vectorize, and Hyperdrive require account-level product permissions."
        )
    ]

    static func accountContextMessage(tokenMode: AuthTokenMode) -> String {
        "The configured account ID is missing or invalid. Enter the 32-character Cloudflare account ID that owns this account token, then reconnect or refresh."
    }

    static func accountCapabilityMessage(_ message: String, tokenMode: AuthTokenMode) -> String {
        "\(message)\n\(accountContextMessage(tokenMode: tokenMode))"
    }
}

struct TokenPermissionGuidanceRows: View {
    var body: some View {
        ForEach(Array(TokenPermissionGuidance.minimumRows.enumerated()), id: \.offset) { _, row in
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                Text(row.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}
