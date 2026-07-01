# AGENTS.md

## Project Identity

`CFPanel` is a native SwiftUI iOS client for managing Cloudflare from iPhone and iPad.

The product is positioned as:

- A fast mobile operations console for Cloudflare users, developers, and operators.
- A direct client-to-Cloudflare app with no relay backend.
- A tool for incident response, DNS changes, Workers and Pages inspection, cache/security actions, and account-level platform visibility.

Important trust model:

- This app handles high-value Cloudflare credentials and infrastructure surfaces.
- Any change affecting authentication, storage, telemetry, or network transport should be treated as security-sensitive.
- The app connects directly to Cloudflare public APIs from the device.

## Product Principles

- Mobile-first, operational, low-friction UI.
- Prefer fast paths for common actions; keep advanced controls secondary.
- Keep the app client-side only.
- Minimize unnecessary stored data.
- Use scoped credentials and show only the permissions actually needed.

## Repository Shape

Top-level structure:

- `CFPanel/`: app source.
- `CFPanel.xcodeproj/`: Xcode project.
- `CFPanel/App/Architecture.md`: high-level architecture notes.
- `dev.md`: product vision, privacy model, App Store positioning.
- `OPTIMIZATION_TASKS.md`: ad hoc optimization notes.

Source structure inside `CFPanel/`:

- `App/`: app shell, composition root, root navigation, shared view-model wiring.
- `App/Root/`: app entry and root UI shell.
- `App/ViewModels/`: app-level and feature-support view models.
- `App/ViewModels/Stores/`: shared observable state stores.
- `App/ViewModels/Support/`: shell actions, request context, load-state helpers.
- `Core/Networking/`: Cloudflare API transport and endpoint extensions.
- `Core/Storage/`: Keychain and preference persistence.
- `Domain/Models/`: domain models and UI-safe value projections.
- `Features/`: SwiftUI feature folders by product area.
- `Assets.xcassets/`: app icons and bundled image assets.

Feature folders currently include:

- `Authentication`
- `Monitor`
- `Sites`
- `DNS`
- `Mail`
- `Pages`
- `Workers`
- `DataServices`
- `Rules`
- `Security`
- `Settings`
- `Account`
- `PanicCenter`
- `Common`

## Architecture Summary

CFPanel uses a lightweight SwiftUI + Observation architecture.

Core ideas:

- SwiftUI is the primary UI layer.
- `@Observable` types are preferred for mutable UI state.
- `AppContainer` is the composition root.
- `AppModel` is the shell model, not the business-state dump.
- Feature views should depend on feature-specific view models or stores.
- Business state is distributed across focused stores rather than centralized in one giant object.

Important architectural boundaries:

- Do not turn `AppModel` into a catch-all service locator.
- Put Cloudflare request orchestration in feature view models or dedicated services.
- Use shared stores only when state is genuinely cross-feature.
- Use shell action bridges for alerts, logging, and navigation concerns.

## Authentication Model

There are two main auth paths:

- OAuth
- Account/API token

Authentication code lives primarily in:

- `CFPanel/Features/Authentication/AuthenticationView.swift`
- `CFPanel/Features/Authentication/AuthenticationViewModel.swift`
- `CFPanel/Features/Authentication/OAuthSessionStore.swift`
- `CFPanel/Features/Authentication/OAuthScopeCatalog.swift`
- `CFPanel/Features/Authentication/OAuthCoordinator.swift`
- `CFPanel/Features/Authentication/CredentialPersistenceService.swift`
- `CFPanel/Features/Authentication/AuthenticatedWorkspaceLoader.swift`

Rules for auth-related changes:

- Treat all credential handling as security-sensitive.
- Tokens belong in Keychain, not plain preferences.
- Non-secret UI preferences may use `@CloudStorage`.
- Do not guess Cloudflare OAuth scope IDs.
- When adjusting OAuth scopes, verify against Cloudflare `/oauth/scopes` output or official docs.
- Prefer exposing only the scopes CFPanel actually uses.

If the repository contains a local OAuth scope dump such as `response.json`, use it as a reference artifact for current scope IDs before editing scope catalogs.

## Cloudflare API Layer

The shared API surface is `CloudflareAPI` in `Core/Networking/`.

Pattern:

- Endpoint groups are split into extensions like `CloudflareAPI+DNS.swift`, `CloudflareAPI+Pages.swift`, `CloudflareAPI+Workers.swift`, etc.
- Transport, retries, authorization, and decoding live in `CloudflareAPI+Transport.swift`.

When editing networking code:

- Preserve direct device-to-Cloudflare behavior.
- Keep authorization handling centralized.
- Avoid duplicating transport logic in feature code.
- Redact sensitive identifiers in diagnostics/logging.
- Be careful with unauthorized-session handling and retry behavior.

## Data and Privacy Rules

The intended storage model is:

- Secrets: Keychain.
- Non-secret synced preferences: `@CloudStorage` / iCloud KVS.
- Cloudflare operational data: memory only unless there is a very strong reason otherwise.

Do not:

- Add hidden telemetry.
- Send credentials to non-Cloudflare endpoints.
- Persist infrastructure inventory casually.
- Store secrets in `UserDefaults` or arbitrary files.

## UI and UX Guidance

This project is not a generic dashboard skin. It is an operational tool.

Prefer:

- Short paths for primary actions.
- Progressive disclosure for advanced settings.
- Clear distinction between common flows and expert-only flows.
- High-signal cards and controls over explanatory clutter.

Avoid:

- Repeating the same meaning with multiple controls.
- Large informational blocks that users will skip in primary flows.
- Mobile-hostile dense desktop-style settings walls.

Recent UI direction around auth:

- OAuth quick presets are the primary path.
- Fine-grained scope editing is secondary.
- CTA placement should favor visibility without adding noise.
- Token login should feel like a compact form, not a docs page.

## Code Style

- SwiftUI-first. Avoid UIKit unless truly necessary.
- Prefer modern SwiftUI APIs.
- Use `NavigationStack`.
- Prefer `foregroundStyle`, modern `alert`, modern `onChange`, etc.
- Prefer `LocalizedStringResource` for user-facing enum titles and copy surfaces where appropriate.
- Keep types focused and grouped by feature/domain.
- Split large API surfaces into extension files by product area.

## Build and Tooling Notes

- Main Xcode project: `CFPanel.xcodeproj`
- Main target/scheme: `CFPanel`
- Stack: Swift 5.9+, SwiftUI, async/await, Observation

When using shell commands in this repository, local project convention prefers prefixing commands with `rtk`.

Examples:

- `rtk rg --files`
- `rtk sed -n '1,200p' <file>`
- `rtk git diff`

## High-Value Files To Read First

When onboarding into the codebase, start with:

1. `dev.md`
2. `CFPanel/App/Architecture.md`
3. `CFPanel/App/AppContainer.swift`
4. `CFPanel/Features/Authentication/AuthenticationViewModel.swift`
5. `CFPanel/Core/Networking/CloudflareAPI+Transport.swift`

## Safe Change Strategy

For most changes:

1. Identify the feature folder first.
2. Confirm whether state lives in a feature view model, a shared store, or a dedicated service.
3. Check whether the behavior is zone-scoped, account-scoped, or shell-scoped.
4. If touching OAuth or permissions, verify real Cloudflare scope IDs before editing.
5. Prefer small, local changes over broad architectural rewrites.

## Special Warnings

- Cloudflare permission names and OAuth scope IDs do not always match API token naming intuition.
- Some Cloudflare product permissions are split more finely than expected.
- UI changes in auth flows can easily make primary actions harder to find on mobile.
- This app is security-trust-sensitive; “technically works” is not enough for auth or transport changes.

## Definition Of A Good Change Here

A good change in CFPanel usually:

- Improves speed or clarity for mobile operations.
- Preserves the direct-to-Cloudflare trust model.
- Keeps auth and credential handling conservative.
- Fits the existing feature boundaries.
- Avoids unnecessary UI noise.
