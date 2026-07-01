import Foundation

nonisolated struct OAuthFeaturePermission: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let readScopes: [String]
    let editScopes: [String]
    let isRequired: Bool

    var isEnabled: Bool
    var canEdit: Bool = false

    var hasEditOption: Bool { editScopes.isEmpty == false }
}

enum OAuthScopeCatalog {
    static let defaultPermissions: [OAuthFeaturePermission] = [
        .init(
            id: "account",
            title: "Account Context",
            description: "Load account-level context and account-owned product surfaces inside CFPanel.",
            icon: "person.crop.circle",
            readScopes: ["account-settings.read"],
            editScopes: [],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "zones",
            title: "Zones",
            description: "Load sites, zone status, and site-level details.",
            icon: "globe",
            readScopes: ["zone.read"],
            editScopes: [],
            isRequired: true,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "dns",
            title: "DNS",
            description: "Inspect and edit DNS records when needed.",
            icon: "network",
            readScopes: ["dns.read"],
            editScopes: ["dns.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "analytics",
            title: "Analytics",
            description: "Show traffic charts, usage metrics, and account-level analytics.",
            icon: "chart.bar",
            readScopes: ["analytics.read", "account-analytics.read"],
            editScopes: [],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "zone_settings",
            title: "Site Settings",
            description: "Load SSL/TLS, security, caching, and edge feature settings.",
            icon: "gearshape.2",
            readScopes: ["zone-settings.read"],
            editScopes: ["zone-settings.write", "cache.purge"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "waf",
            title: "WAF",
            description: "Inspect or update zone WAF controls.",
            icon: "shield",
            readScopes: ["zone-waf.read"],
            editScopes: ["zone-waf.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "rules",
            title: "Rulesets",
            description: "Review and update zone rulesets, redirects, origin rules, and transform rules.",
            icon: "line.3.horizontal.decrease.circle",
            readScopes: ["config-settings.read", "origin.read", "dynamic-redirect.read", "transform-rules.read"],
            editScopes: ["config-settings.write", "origin.write", "dynamic-redirect.write", "transform-rules.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "pages",
            title: "Pages",
            description: "Inspect Pages projects and deployment metadata exposed to OAuth clients.",
            icon: "doc.richtext",
            readScopes: ["page.read"],
            editScopes: ["page.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "workers_scripts",
            title: "Workers Scripts",
            description: "Load Workers scripts, deployments, versions, and runtime configuration.",
            icon: "bolt.circle",
            readScopes: ["workers-scripts.read"],
            editScopes: ["workers-scripts.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "workers_routes",
            title: "Workers Routes",
            description: "Inspect and manage route bindings and exposed Worker domains.",
            icon: "point.3.connected.trianglepath.dotted",
            readScopes: ["workers-routes.read"],
            editScopes: ["workers-routes.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "r2",
            title: "R2",
            description: "Browse R2 buckets and object storage metadata.",
            icon: "archivebox",
            readScopes: ["workers-r2.read"],
            editScopes: ["workers-r2.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "d1",
            title: "D1",
            description: "Inspect D1 databases and metadata.",
            icon: "cylinder",
            readScopes: ["d1.read"],
            editScopes: ["d1.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "kv",
            title: "KV",
            description: "Browse and edit Workers KV namespaces and keys.",
            icon: "square.grid.2x2",
            readScopes: ["workers-kv-storage.read"],
            editScopes: ["workers-kv-storage.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "queues",
            title: "Queues",
            description: "Inspect queue catalogs, producer/consumer counts, and queue details.",
            icon: "point.3.filled.connected.trianglepath.dotted",
            readScopes: ["queues.read"],
            editScopes: ["queues.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "vectorize",
            title: "Vectorize",
            description: "Inspect Vectorize indexes and metadata indexes tied to the selected account.",
            icon: "sparkles.rectangle.stack",
            readScopes: ["vectorize.read"],
            editScopes: ["vectorize.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "mail_routing",
            title: "Email Routing",
            description: "Inspect routing rules, destination addresses, and inbound email configuration.",
            icon: "envelope.badge",
            readScopes: ["email-routing-rule.read", "email-routing-address.read"],
            editScopes: ["email-routing-rule.write", "email-routing-address.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "mail_sending",
            title: "Email Sending",
            description: "Inspect sending domains and email sending configuration exposed by Cloudflare.",
            icon: "paperplane",
            readScopes: ["email-sending.read"],
            editScopes: ["email-sending.write"],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        ),
        .init(
            id: "audit",
            title: "Audit Logs",
            description: "Review account activity and security-related audit trails surfaced by Cloudflare.",
            icon: "clock.badge.exclamationmark",
            readScopes: ["account-logs.read", "access-audit-log.read"],
            editScopes: [],
            isRequired: false,
            isEnabled: true,
            canEdit: false
        )
    ]

    static func buildScopeString(from permissions: [OAuthFeaturePermission]) -> String {
        buildScopeSet(from: permissions)
            .sorted()
            .joined(separator: " ")
    }

    static func buildScopeSet(from permissions: [OAuthFeaturePermission]) -> Set<String> {
        var scopes = Set<String>()

        for permission in permissions where permission.isEnabled {
            permission.readScopes.forEach { scopes.insert($0) }

            if permission.canEdit {
                permission.editScopes.forEach { scopes.insert($0) }
            }
        }

        return scopes
    }
}
