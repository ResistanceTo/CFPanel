import SwiftUI

struct AuthenticationView: View {
    @Environment(AuthenticationViewModel.self) private var authenticationViewModel
    @Binding var pinnedZoneID: String

    private let websiteURL = URL(string: "https://cfpanel.zhaohe.org")!
    private let githubURL = URL(string: "https://github.com/resistanceto/CFPanel")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AuthenticationHeroCard(isOAuthConfigured: authenticationViewModel.isOAuthConfigured)

                    VStack(spacing: 14) {
                        NavigationLink {
                            OAuthPermissionSelectionView()
                                .environment(authenticationViewModel)
                        } label: {
                            AuthActionButtonLabel(
                                title: authenticationViewModel.isAuthorizingWithOAuth ? "Authorizing..." : "Continue with Cloudflare",
                                subtitle: "Pick the scope set first, then continue in the browser",
                                icon: "lock.shield.fill",
                                emphasized: true
                            )
                        }
                        .disabled(authenticationViewModel.isOAuthConfigured == false)

                        NavigationLink {
                            AccountTokenSignInView(pinnedZoneID: $pinnedZoneID)
                                .environment(authenticationViewModel)
                        } label: {
                            AuthActionButtonLabel(
                                title: "Use Account Token",
                                subtitle: "Paste a token and account ID for direct access",
                                icon: "key.horizontal.fill",
                                emphasized: false
                            )
                        }
                    }

                    AuthenticationLinksCard(
                        websiteURL: websiteURL,
                        githubURL: githubURL
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AuthenticationBackground().ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

private struct OAuthPermissionSelectionView: View {
    @Environment(AuthenticationViewModel.self) private var authenticationViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                OAuthPermissionHeroCard(
                    selectedScopeCount: authenticationViewModel.oauthSelectedScopes.count,
                    selectedPreset: authenticationViewModel.selectedOAuthPreset
                )

                AuthenticationCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Quick Access")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        VStack(spacing: 10) {
                            OAuthPresetCard(
                                title: "Read Only",
                                systemImage: "eye.fill",
                                accent: .blue,
                                isSelected: authenticationViewModel.selectedOAuthPreset == .readOnly
                            ) {
                                authenticationViewModel.applyOAuthPreset(.readOnly)
                            }

                            OAuthPresetCard(
                                title: "Read / Write",
                                systemImage: "square.and.pencil",
                                accent: .orange,
                                isSelected: authenticationViewModel.selectedOAuthPreset == .readWrite
                            ) {
                                authenticationViewModel.applyOAuthPreset(.readWrite)
                            }
                        }

                        Text("Need something custom? Fine-tune the module switches below.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary.opacity(0.72))
                    }
                }

                AuthenticationCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Scope Modules")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        Text("Need something custom? Adjust individual modules here. Each row shows the real Cloudflare scope IDs taken from your `/oauth/scopes` response.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 12) {
                            ForEach(authenticationViewModel.oauthPermissions) { permission in
                                OAuthPermissionRow(
                                    permission: permission,
                                    onToggle: { authenticationViewModel.toggleOAuthPermission(permission.id) },
                                    onToggleEdit: { authenticationViewModel.toggleOAuthEditPermission(permission.id) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 96)
        }
        .background(AuthenticationBackground().ignoresSafeArea())
        .navigationTitle("OAuth Access")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            AuthenticationFloatingActionBar {
                Button {
                    authenticationViewModel.startOAuthAuthorization()
                } label: {
                    HStack(spacing: 10) {
                        if authenticationViewModel.isAuthorizingWithOAuth {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(authenticationViewModel.isAuthorizingWithOAuth ? "Authorizing..." : "Sign in with Cloudflare Account")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(authenticationViewModel.isAuthorizingWithOAuth || authenticationViewModel.isOAuthConfigured == false)
            }
        }
    }
}

private struct AccountTokenSignInView: View {
    @Environment(AuthenticationViewModel.self) private var authenticationViewModel
    @Binding var pinnedZoneID: String

    @State private var isShowingTokenHelp = false
    @State private var isShowingToken = false

    private let tokenManagementURL = URL(string: "https://dash.cloudflare.com/profile/api-tokens")!
    private let tokenDocsURL = URL(string: "https://developers.cloudflare.com/fundamentals/api/get-started/create-token/")!

    var body: some View {
        @Bindable var authenticationViewModel = authenticationViewModel

        ScrollView {
            VStack(spacing: 18) {
                AuthenticationCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Storage", systemImage: "externaldrive.badge.checkmark")
                                .font(.headline)
                            Spacer()
                        }

                        Picker("Token Storage", selection: $authenticationViewModel.credentialStorageMode) {
                            ForEach(CredentialStorageMode.allCases) { mode in
                                Text(mode.shortTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(authenticationViewModel.credentialStorageMode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                AuthenticationCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Account ID", systemImage: "building.2.crop.circle")
                            .font(.headline)

                        AuthFieldShell {
                            TextField("32-character Account ID", text: $authenticationViewModel.accountIDInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .submitLabel(.done)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                AuthenticationCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("API Token", systemImage: "key.fill")
                                .font(.headline)

                            Spacer()

                            Button {
                                isShowingToken.toggle()
                            } label: {
                                Label(isShowingToken ? "Hide" : "Show", systemImage: isShowingToken ? "eye.slash" : "eye")
                                    .font(.footnote.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        AuthFieldShell {
                            Group {
                                if isShowingToken {
                                    TextField("API token starting with cfat_", text: $authenticationViewModel.tokenInput)
                                } else {
                                    SecureField("API token starting with cfat_", text: $authenticationViewModel.tokenInput)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .submitLabel(.done)
                            .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Button {
                                Task {
                                    await authenticationViewModel.signIn(
                                        preferredZoneID: pinnedZoneID,
                                        tokenMode: .account,
                                        accountID: authenticationViewModel.accountIDInput
                                    )
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if authenticationViewModel.isAuthenticating {
                                        ProgressView()
                                            .tint(.white)
                                    }

                                    Text(authenticationViewModel.isAuthenticating ? "Checking Token..." : "Connect with Account Token")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(authenticationViewModel.isAuthenticating)

                            Button {
                                isShowingTokenHelp = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.title3.weight(.semibold))
                                    .frame(width: 44, height: 44)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                AuthenticationCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("How to get a token", systemImage: "checkmark.shield")
                                .font(.headline)

                            Spacer()

                            Button("Open Help") {
                                isShowingTokenHelp = true
                            }
                            .font(.footnote.weight(.semibold))
                        }

                        Text("Create a scoped API token in Cloudflare Dashboard, then paste it here with the matching account ID.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(AuthenticationBackground().ignoresSafeArea())
        .navigationTitle("Account Token")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingTokenHelp) {
            TokenHelpSheet(
                tokenManagementURL: tokenManagementURL,
                tokenDocsURL: tokenDocsURL
            )
        }
    }
}

private struct AuthenticationBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 0.95, green: 0.96, blue: 0.99),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.orange.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 120, y: -240)

            Circle()
                .fill(Color.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 36)
                .offset(x: -140, y: 260)
        }
    }
}

private struct AuthenticationHeroCard: View {
    let isOAuthConfigured: Bool

    var body: some View {
        AuthenticationCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CFPanel")
                            .font(.system(size: 34, weight: .bold, design: .rounded))

                        Text("A focused Cloudflare control room for iPhone and iPad.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.orange.opacity(0.14))
                            .frame(width: 68, height: 68)
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 12) {
                    AuthenticationPill(
                        title: isOAuthConfigured ? "OAuth Ready" : "OAuth Missing",
                        tint: isOAuthConfigured ? .green : .orange,
                        systemImage: isOAuthConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )

                    AuthenticationPill(
                        title: "Private by Design",
                        tint: .blue,
                        systemImage: "lock.fill"
                    )
                }

                Text("Choose browser-based OAuth when you want flexible scopes, or use an account token when you need a direct manual setup.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AuthenticationLinksCard: View {
    let websiteURL: URL
    let githubURL: URL

    var body: some View {
        AuthenticationCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Project Links")
                    .font(.headline)

                Link(destination: websiteURL) {
                    AuthenticationLinkRow(
                        imageName: "cfpanel_logo",
                        title: "Official Website",
                        detail: "cfpanel.zhaohe.org"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 50)

                Link(destination: githubURL) {
                    AuthenticationLinkRow(
                        imageName: "github_logo",
                        title: "GitHub",
                        detail: "Open the source repository"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct OAuthPermissionHeroCard: View {
    let selectedScopeCount: Int
    let selectedPreset: OAuthPermissionPreset?

    private var presetTitle: String {
        switch selectedPreset {
        case .readOnly:
            "Read Only"
        case .readWrite:
            "Read / Write"
        case nil:
            "Custom Selection"
        }
    }

    var body: some View {
        AuthenticationCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review OAuth Access")
                            .font(.title3.bold())

                        Text("Pick the scope set here first. The choices on this screen are the exact scopes CFPanel will send to Cloudflare.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(12)
                        .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 12) {
                    AuthenticationMetricTile(
                        value: selectedScopeCount.formatted(),
                        label: "Selected Scopes",
                        tint: .orange
                    )

                    AuthenticationMetricTile(
                        value: presetTitle,
                        label: "Preset",
                        tint: .blue
                    )
                }
            }
        }
    }
}

private struct AccountTokenHeroCard: View {
    var body: some View {
        AuthenticationCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect with an Account Token")
                            .font(.title3.bold())

                        Text("Paste a Cloudflare account token and its matching account ID. This path is precise, manual, and good for tightly scoped access.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "key.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(12)
                        .background(.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 12) {
                    AuthenticationPill(
                        title: "Manual Setup",
                        tint: .blue,
                        systemImage: "slider.horizontal.below.rectangle"
                    )

                    AuthenticationPill(
                        title: "Scoped Token",
                        tint: .green,
                        systemImage: "checkmark.shield.fill"
                    )
                }
            }
        }
    }
}

private struct AuthenticationCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 10)
    }
}

private struct AuthenticationPill: View {
    let title: String
    let tint: Color
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct AuthenticationMetricTile: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AuthenticationLinkRow: View {
    let imageName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .padding(8)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

private struct AuthFieldShell<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
    }
}

private struct AuthenticationBottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            content
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .background(.regularMaterial)
        }
    }
}

private struct AuthenticationFloatingActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange,
                                Color(red: 0.96, green: 0.47, blue: 0.15)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
    }
}

private struct AuthActionButtonLabel: View {
    let title: String
    let subtitle: String
    let icon: String
    let emphasized: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill((emphasized ? Color.white.opacity(0.20) : Color.accentColor.opacity(0.12)))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(emphasized ? .white.opacity(0.86) : .secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .opacity(0.9)
        }
        .foregroundStyle(emphasized ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            Group {
                if emphasized {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange,
                                    Color(red: 0.96, green: 0.47, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(emphasized ? Color.clear : Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: emphasized ? .orange.opacity(0.20) : .black.opacity(0.04), radius: 14, x: 0, y: 8)
    }
}

private struct OAuthPresetCard: View {
    let title: String
    let systemImage: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? accent.opacity(0.18) : accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSelected ? accent : .primary)

                    Text(isSelected ? "Currently used for the Cloudflare browser sign-in." : "Tap to switch this authorization mode.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.82) : Color.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isSelected ? accent : Color.secondary.opacity(0.45))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.72) : Color(.separator), lineWidth: isSelected ? 1.6 : 1)
            )
            .shadow(color: isSelected ? accent.opacity(0.16) : .clear, radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct OAuthPermissionRow: View {
    let permission: OAuthFeaturePermission
    let onToggle: () -> Void
    let onToggleEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(permission.title)
                            .font(.subheadline.weight(.semibold))

                        if permission.isRequired {
                            Text("Required")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.14), in: Capsule())
                        }
                    }

                    Text(permission.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    OAuthPermissionToggleControl(
                        title: "Read",
                        isOn: permission.isEnabled,
                        isDisabled: permission.isRequired,
                        action: onToggle
                    )

                    if permission.hasEditOption {
                        OAuthPermissionToggleControl(
                            title: "Write",
                            isOn: permission.canEdit,
                            isDisabled: permission.isEnabled == false,
                            action: onToggleEdit
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .opacity(permission.isEnabled ? 1 : 0.6)
    }
}

private struct OAuthPermissionToggleControl: View {
    let title: String
    let isOn: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { _ in action() }
            ))
            .labelsHidden()
            .disabled(isDisabled)
        }
    }
}

private struct TokenGuideStep: View {
    let index: Int
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(index.formatted())
                .font(.subheadline.bold())
                .frame(width: 24, height: 24)
                .background(.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TokenHelpSheet: View {
    let tokenManagementURL: URL
    let tokenDocsURL: URL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How to get a Cloudflare API token")
                            .font(.title3.bold())
                        Text("Create a scoped API token in Cloudflare Dashboard, then paste it into CFPanel.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        TokenGuideStep(
                            index: 1,
                            title: "Open the account token screen",
                            detail: "Create the token in Manage Account > API Tokens."
                        )
                        TokenGuideStep(
                            index: 2,
                            title: "Create a token, not a Global API Key",
                            detail: "Use a scoped API token so CFPanel only gets the permissions you intend."
                        )
                        TokenGuideStep(
                            index: 3,
                            title: "Add minimum permissions",
                            detail: "Start with Zone:Read. Add product permissions only for the surfaces you plan to manage, such as DNS, Cache Purge, Zone Settings, Pages, Workers, R2, D1, KV, Queues, Vectorize, or Hyperdrive."
                        )
                        TokenGuideStep(
                            index: 4,
                            title: "Enter the matching account ID",
                            detail: "Paste the 32-character Cloudflare account ID that owns this API token so CFPanel can verify it against /accounts/{account_id}/tokens/verify."
                        )
                        TokenGuideStep(
                            index: 5,
                            title: "Copy it once",
                            detail: "Cloudflare only shows the full token value when it is created."
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Link(destination: tokenManagementURL) {
                            Label("Open API Tokens Page", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)

                        Link(destination: tokenDocsURL) {
                            Label("Open Official Token Guide", systemImage: "book")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Token Help")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
