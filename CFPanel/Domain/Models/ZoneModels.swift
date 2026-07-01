import Foundation
import SwiftUI

nonisolated struct CloudflareZone: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let status: String

    var statusTitle: LocalizedStringResource {
        switch status.lowercased() {
        case "active": "Active"
        case "pending": "Pending"
        case "moved": "Moved"
        default: "Unknown"
        }
    }
}

nonisolated enum CloudflareZoneType: String, Codable, Sendable {
    case full
    case partial
    case secondary
    case internalType = "internal"

    var title: LocalizedStringResource {
        switch self {
        case .full: "Full"
        case .partial: "Partial"
        case .secondary: "Secondary"
        case .internalType: "Internal"
        }
    }
}

nonisolated struct CloudflareZoneDetails: Codable, Sendable {
    nonisolated struct Account: Codable, Sendable {
        let id: String?
        let name: String?
    }

    let id: String
    let name: String
    let status: String
    let type: CloudflareZoneType?
    let paused: Bool?
    let developmentMode: Int?
    let nameServers: [String]
    let originalRegistrar: String?
    let createdOn: Date?
    let modifiedOn: Date?
    let activatedOn: Date?
    let account: Account?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case type
        case paused
        case developmentMode = "development_mode"
        case nameServers = "name_servers"
        case originalRegistrar = "original_registrar"
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case activatedOn = "activated_on"
        case account
    }

    var statusTitle: LocalizedStringResource {
        switch status.lowercased() {
        case "active": "Active"
        case "pending": "Pending"
        case "initializing": "Initializing"
        case "moved": "Moved"
        default: "Unknown"
        }
    }
}

nonisolated enum ZoneMode: String, Codable, Sendable {
    case standard
    case cdnOnly = "cdn_only"
    case dnsOnly = "dns_only"

    var title: LocalizedStringResource {
        switch self {
        case .standard: "Standard"
        case .cdnOnly: "CDN Only"
        case .dnsOnly: "DNS Only"
        }
    }
}

nonisolated struct ZoneDNSSettings: Codable, Sendable {
    nonisolated struct NameServers: Codable, Sendable {
        let type: String?
        let nsSet: Int?

        enum CodingKeys: String, CodingKey {
            case type
            case nsSet = "ns_set"
        }
    }

    let flattenAllCNAMES: Bool
    let multiProvider: Bool
    let foundationDNS: Bool
    let nsTTL: Int
    let zoneMode: ZoneMode
    let nameservers: NameServers?

    enum CodingKeys: String, CodingKey {
        case flattenAllCNAMES = "flatten_all_cnames"
        case multiProvider = "multi_provider"
        case foundationDNS = "foundation_dns"
        case nsTTL = "ns_ttl"
        case zoneMode = "zone_mode"
        case nameservers
    }
}

nonisolated struct ZoneControlSettings: Sendable, Equatable {
    var alwaysUseHTTPS = false
    var automaticHTTPSRewrites = false
    var developmentMode = false
    var browserIntegrityCheck = false
    var alwaysOnline = false
    var waf = false
    var botFightMode = false

    static let empty = ZoneControlSettings()
}

nonisolated struct ZoneCacheSettings: Sendable, Equatable {
    var cacheLevel: CacheLevel = .aggressive
    var browserCacheTTL: Int = 14400

    static let empty = ZoneCacheSettings()

    var browserCacheTTLTitle: String {
        switch browserCacheTTL {
        case 0: "Respect Existing Headers"
        case 1800: "30 Minutes"
        case 3600: "1 Hour"
        case 7200: "2 Hours"
        case 10800: "3 Hours"
        case 14400: "4 Hours"
        case 28800: "8 Hours"
        case 43200: "12 Hours"
        case 86400: "1 Day"
        case 172800: "2 Days"
        case 259200: "3 Days"
        case 345600: "4 Days"
        case 432000: "5 Days"
        case 691200: "8 Days"
        case 1382400: "16 Days"
        case 2073600: "24 Days"
        case 2678400: "1 Month"
        case 5356800: "2 Months"
        case 16070400: "6 Months"
        case 31536000: "1 Year"
        default: "\(browserCacheTTL) Seconds"
        }
    }

    static let browserCacheTTLOptions: [Int] = [
        0, 1800, 3600, 7200, 14400, 28800, 43200, 86400, 172800,
        345600, 691200, 2678400, 5356800, 16070400, 31536000
    ]

    static func formatTTL(_ ttl: Int) -> String {
        String(ZoneCacheSettings(browserCacheTTL: ttl).browserCacheTTLTitle)
    }
}

nonisolated struct ZoneAdvancedSettings: Sendable, Equatable {
    var http3 = false
    var tls13 = false
    var webSockets = false
    var zeroRTT = false
    var ipGeolocation = false
    var webP = false

    static let empty = ZoneAdvancedSettings()
}

nonisolated enum ZoneControlToggle: String, CaseIterable, Identifiable, Sendable {
    case alwaysUseHTTPS = "always_use_https"
    case automaticHTTPSRewrites = "automatic_https_rewrites"
    case developmentMode = "development_mode"
    case browserIntegrityCheck = "browser_check"
    case alwaysOnline = "always_online"
    case waf
    case botFightMode = "bot_fight_mode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alwaysUseHTTPS: "Always Use HTTPS"
        case .automaticHTTPSRewrites: "Automatic HTTPS Rewrites"
        case .developmentMode: "Development Mode"
        case .browserIntegrityCheck: "Browser Integrity Check"
        case .alwaysOnline: "Always Online"
        case .waf: "Cloudflare WAF"
        case .botFightMode: "Bot Fight Mode"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .alwaysUseHTTPS:
            "Redirect all requests to HTTPS at the edge."
        case .automaticHTTPSRewrites:
            "Rewrite mixed-content links to HTTPS when possible."
        case .developmentMode:
            "Bypass edge cache for up to 3 hours while making changes."
        case .browserIntegrityCheck:
            "Challenge suspicious clients with malformed or missing browser headers."
        case .alwaysOnline:
            "Serve archived content when the origin is offline."
        case .waf:
            "Enable Cloudflare's Web Application Firewall for this zone."
        case .botFightMode:
            "Block bots detected by Cloudflare's threat intelligence. Free plan feature."
        }
    }
}

nonisolated enum ZoneAdvancedToggle: String, CaseIterable, Identifiable, Sendable {
    case http3
    case tls13 = "tls_1_3"
    case webSockets = "websocket"
    case zeroRTT = "0rtt"
    case ipGeolocation = "ip_geolocation"
    case webP = "webp"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .http3: "HTTP/3"
        case .tls13: "TLS 1.3"
        case .webSockets: "WebSockets"
        case .zeroRTT: "0-RTT"
        case .ipGeolocation: "IP Geolocation"
        case .webP: "WebP Optimization"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .http3:
            "Serve eligible traffic over QUIC and HTTP/3 at the edge."
        case .tls13:
            "Allow visitors to negotiate TLS 1.3 with Cloudflare."
        case .webSockets:
            "Permit WebSocket connections through Cloudflare's edge."
        case .zeroRTT:
            "Resume compatible TLS sessions with 0-RTT data for lower latency."
        case .ipGeolocation:
            "Expose visitor geolocation headers to the origin."
        case .webP:
            "Automatically optimize compatible image delivery with WebP."
        }
    }
}

nonisolated enum CacheLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case bypass = "bypass"
    case basic = "basic"
    case simplified = "simplified"
    case aggressive = "aggressive"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bypass: "Bypass"
        case .basic: "Basic"
        case .simplified: "Simplified"
        case .aggressive: "Aggressive"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .bypass:
            "Cloudflare does not cache any responses."
        case .basic:
            "Cache only when there are no query strings in the URL."
        case .simplified:
            "Cache the same resource for all users regardless of query strings."
        case .aggressive:
            "Cache all static content, including responses with query strings."
        }
    }
}

nonisolated enum SecurityLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case essentiallyOff = "essentially_off"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case underAttack = "under_attack"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .essentiallyOff: "Essentially Off"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .underAttack: "Under Attack"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .essentiallyOff:
            "Only the most aggressive threats are challenged. Use with caution."
        case .low:
            "Challenges only high-confidence threats based on Cloudflare's threat intelligence."
        case .medium:
            "Challenges visitors with a moderate threat score. Balanced default."
        case .high:
            "Challenges visitors with any elevated threat score."
        case .underAttack:
            "Applies an aggressive JavaScript challenge to all visitors. Use during active DDoS attacks only."
        }
    }
}

nonisolated struct HSTSSettings: Codable, Sendable, Equatable {
    var enabled: Bool
    var maxAge: Int
    var includeSubdomains: Bool
    var preload: Bool
    var nosniff: Bool

    enum CodingKeys: String, CodingKey {
        case enabled
        case maxAge = "max_age"
        case includeSubdomains = "include_subdomains"
        case preload
        case nosniff
    }

    static let disabled = HSTSSettings(
        enabled: false, maxAge: 0,
        includeSubdomains: false, preload: false, nosniff: false
    )
}

nonisolated enum CloudflareSSLMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case flexible
    case full
    case strict
    case originPull = "origin_pull"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .off: "Off"
        case .flexible: "Flexible"
        case .full: "Full"
        case .strict: "Full (Strict)"
        case .originPull: "Strict (SSL-Only Origin Pull)"
        }
    }
}

nonisolated enum MinimumTLSVersion: String, CaseIterable, Identifiable, Codable, Sendable {
    case v10 = "1.0"
    case v11 = "1.1"
    case v12 = "1.2"
    case v13 = "1.3"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .v10: "TLS 1.0"
        case .v11: "TLS 1.1"
        case .v12: "TLS 1.2"
        case .v13: "TLS 1.3"
        }
    }
}

nonisolated struct EdgeTLSSettings: Sendable, Equatable {
    var sslMode: CloudflareSSLMode = .full
    var minimumTLSVersion: MinimumTLSVersion = .v12
    var hsts: HSTSSettings = .disabled

    static let empty = EdgeTLSSettings()
}
