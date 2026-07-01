# CFPanel – Copilot Instructions

CFPanel is a native iOS client for managing Cloudflare accounts. It connects directly to the Cloudflare public API with no intermediate server (client-side only).

## Build

```bash
# Build
xcodebuild -project CFPanel.xcodeproj -scheme CFPanel -destination 'platform=iOS Simulator,name=iPhone 16' build

# Clean build
xcodebuild -project CFPanel.xcodeproj -scheme CFPanel clean build
```

There is no test target yet. Validate changes by building and exercising the relevant flow in the simulator.

## Architecture

The app has three layers:

- **`CFPanel/App/`** — App entry point and central state. `AppModel` is an `@Observable @MainActor` class that is the single source of truth for all UI state. It is injected at the root and consumed in views via `@Environment(AppModel.self)`. `AppModel` is split across extension files by domain: `AppModel+Auth.swift`, `AppModel+DNS.swift`, `AppModel+ZoneServices.swift`, etc.

- **`CFPanel/Core/`** — Infrastructure with no SwiftUI dependencies.
  - `Networking/CloudflareAPI.swift` — A Swift `actor` singleton (`CloudflareAPI.shared`) that owns the `URLSession` and all HTTP logic. API surface is split into extensions by product area (`CloudflareAPI+DNS.swift`, `CloudflareAPI+Rules.swift`, etc.). All requests go through the transport helpers in `CloudflareAPI+Transport.swift`.
  - `Storage/KeychainTokenStore.swift` — Persists API credentials to Keychain with iCloud sync (`kSecAttrSynchronizable`).
  - `Storage/CloudStorage.swift` — Custom `@CloudStorage` property wrapper backed by `NSUbiquitousKeyValueStore` for synced user preferences.

- **`CFPanel/Features/`** — SwiftUI views organized by feature folder (Authentication, Dashboard, DNS, PanicCenter, Rules, Settings, etc.). Views read from and call methods on `AppModel`; they do not call `CloudflareAPI` directly.

**Data persistence policy:** API credentials → Keychain. User preferences → `@CloudStorage` (iCloud KVS). Business data (DNS records, analytics, zone info) → RAM only, fetched fresh every launch.

## Key Conventions

**State management:** Use `@Observable` (not `ObservableObject`). Non-observed stored properties inside `@Observable` types must be marked `@ObservationIgnored`.

**Storage:**
- Use `@CloudStorage("key")` for any synced user preference. Never write `NSUbiquitousKeyValueStore` directly.
- Use `KeychainTokenStore` for credentials. Never store tokens in `UserDefaults` or files.

**Networking:** All API calls are made via `CloudflareAPI.shared`. GET requests automatically retry up to 2 times on HTTP 429 and 5xx. The API actor handles `Authorization: Bearer <token>` and `Content-Type: application/json` headers. Enable verbose logging with the `CFPANEL_VERBOSE_LOGGING=1` launch environment variable; inspect response bodies with `CFPANEL_LOG_RESPONSE_BODIES=1`.

**Error handling:** Surface errors to the user by calling `appModel.presentError(_:)` or `appModel.presentError(_ message: String)`. This sets `appModel.alert`, which `RootView` displays as a system `Alert`. Throw `CloudflareAPIError` cases for networking/decoding failures.

**Enums in UI:** Never expose `rawValue` in the UI. Add a `title: LocalizedStringResource` property to each enum and use that instead:
```swift
var title: LocalizedStringResource {
    switch self {
    case .brown: "Brown"
    }
}
```

**UI language:** All UI strings must be in English. Use `LocalizedStringResource` (not `String`) for display copy so Xcode can manage localization.

**SwiftUI only:** No UIKit, no Storyboards. Minimum deployment target is iOS 17. Use `NavigationStack` + `navigationDestination`, `task`/`task(id:)`, `foregroundStyle`, and Swift Charts.

**Large types:** Split across extension files by domain rather than growing a single file. Follow the existing `AppModel+<Domain>.swift` and `CloudflareAPI+<Domain>.swift` pattern when adding new capabilities.

**Platforms:** iPhone is P0, iPad is P1, macOS Catalyst is P2.
