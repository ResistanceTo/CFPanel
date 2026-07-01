# CFPanel - Cloudflare Native iOS Console

## 1. Product Vision

CFPanel is a free, native iOS management console for Cloudflare users, developers, and operators.

Core value:

- Manage Cloudflare sites and account-level platform resources from an iPhone.
- Respond quickly during incidents without struggling with the desktop dashboard in a mobile browser.
- Stay client-side only: the app connects directly from the device to Cloudflare's public APIs and does not use a relay server.

Design direction:

- Native SwiftUI experience.
- Quiet operational UI for repeated use.
- Clear separation between site-scoped tools, account-level platform resources, security operations, and settings.

## 2. Technical Baseline

- Language: Swift 5.9+.
- UI framework: SwiftUI.
- Minimum OS: iOS 17.0+.
- Primary platform: iPhone.
- Later platform targets: iPad and macOS Catalyst.
- Networking: native URLSession with async/await.
- Bundle ID: `org.zhaohe.CFPanel`.

## 3. Data Architecture and Privacy

CFPanel has no backend database. Data storage follows these rules:

| Data                     | Storage                       | Sync                     | Notes                                                                                      |
| ------------------------ | ----------------------------- | ------------------------ | ------------------------------------------------------------------------------------------ |
| Cloudflare API token     | iOS Keychain                  | Optional iCloud Keychain | Highest sensitivity. Users choose local-only or synced token storage.                      |
| App preferences          | NSUbiquitousKeyValueStore     | iCloud KVS               | Default site, UI preferences, and non-sensitive settings through `@CloudStorage`.          |
| Cloudflare business data | Memory only                   | None                     | DNS records, rules, analytics, resources, and logs are fetched live and are not persisted. |
| Diagnostics              | Local memory/app storage only | None                     | Request diagnostics redact resource identifiers before display.                            |

Privacy promise:

- CFPanel does not collect user data.
- Cloudflare operational data is requested only as needed.
- Tokens are never sent anywhere except Cloudflare's API.

## 4. First-Stage Product Areas

### 4.1 Authentication

- Guide users to create scoped Cloudflare API tokens.
- Support user tokens and account tokens.
- Validate tokens before entering the app.
- Store credentials in Keychain using the user's selected storage mode.

### 4.2 Monitor

- Show traffic summary for the active site.
- Support 24H, 7D, and 30D analytics views.
- Show audit/activity entry points.
- Provide a direct Incident Response shortcut for fast operational actions.

### 4.3 Sites

- Own active site selection.
- Show zone overview and status.
- Manage DNS records and DNS discovery/import/export tools.
- Expose site-scoped settings such as DNS settings, SSL/TLS, caching, email routing, and advanced edge controls.

### 4.4 Platform

Account-level Cloudflare platform resources are core app capabilities.

- Pages: projects, deployments, custom domains, logs, build cache, and project operations.
- Workers: scripts, deployments, versions, routes, custom domains, workers.dev exposure, and runtime configuration.
- Data Services: KV, R2, D1, Queues, Vectorize, and Hyperdrive.

### 4.5 Security

- Show current security posture for the active site.
- Support security level and Under Attack Mode operations.
- Provide Rules & Policies management.
- Provide Incident Response tools such as cache purge and emergency controls.

### 4.6 Settings

- Default site preference.
- Token type, token storage, token status, and account ID display.
- Permission guidance.
- Asset protection settings for dangerous operations.
- Local diagnostics and request log.
- About and privacy notices.

## 5. UX Principles

- Use `Site` for user-facing zone selection language where possible; use `Zone` when Cloudflare API precision is needed.
- Use `Platform` for account-level products such as Pages, Workers, and Data Services.
- Keep destructive operations hidden behind Advanced Dangerous Mode when appropriate.
- Require device authentication and explicit confirmation for permanent deletes.
- Add confirmation for live-impact changes that can immediately affect production traffic.
- Keep primary lists shallow and load expensive details only after the user opens a detail screen.

## 6. Networking Rules

- Use the shared `CloudflareAPI` actor for Cloudflare requests.
- Every authorized request must include `Authorization: Bearer <token>`.
- JSON requests should include `Content-Type: application/json`.
- Handle unauthorized sessions and API rate limits gracefully.
- Redact account IDs, zone IDs, resource names, keys, and query values in local diagnostics.

## 7. Internationalization

The app's UI copy is written in English first.

User-facing enum values should expose a `LocalizedStringResource` title rather than displaying `rawValue`.

```swift
enum ExampleStatus: String, CaseIterable, Codable, Identifiable, Hashable {
    case active
    case pending

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .active: "Active"
        case .pending: "Pending"
        }
    }
}
```

## 8. App Store Notes

- App title: `CFPanel: Manager for Cloudflare`.
- Subtitle: `DNS, Workers & Cache Control`.
- Privacy label: Data Not Collected.
- Review support: provide Apple with a scoped Cloudflare demo token that can exercise the main read-only flows.
- CFPanel is an independent third-party client built for the Cloudflare ecosystem and powered by Cloudflare's public APIs.
