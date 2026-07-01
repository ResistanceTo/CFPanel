import SwiftUI

struct CountdownConfirmationAction {
    let title: String
    let role: ButtonRole?
    let action: () -> Void
}

private struct CountdownConfirmationDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let action: CountdownConfirmationAction
    let delaySeconds: Int
    let onCancel: (() -> Void)?
    @State private var didConfirm = false

    func body(content: Content) -> some View {
        content
            .sheet(
                isPresented: $isPresented,
                onDismiss: {
                    if didConfirm {
                        didConfirm = false
                    } else {
                        onCancel?()
                    }
                }
            ) {
                CountdownConfirmationSheet(
                    title: title,
                    message: message,
                    action: action,
                    delaySeconds: delaySeconds,
                    isPresented: $isPresented,
                    onConfirm: {
                        didConfirm = true
                    }
                )
                .presentationDetents([.height(300)])
            }
    }
}

private struct CountdownConfirmationSheet: View {
    let title: String
    let message: String
    let action: CountdownConfirmationAction
    let delaySeconds: Int
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visualProgress: Double
    @State private var remainingSeconds: Int
    @State private var canConfirm: Bool

    init(
        title: String,
        message: String,
        action: CountdownConfirmationAction,
        delaySeconds: Int,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.action = action
        self.delaySeconds = delaySeconds
        self.onConfirm = onConfirm
        _isPresented = isPresented
        _visualProgress = State(initialValue: 0)
        _remainingSeconds = State(initialValue: max(delaySeconds, 1))
        _canConfirm = State(initialValue: false)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label(title, systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(action.role == .destructive ? .red : .orange)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .textSelection(.enabled)

                SmoothCountdownProgressBar(
                    progress: visualProgress,
                    tint: action.role == .destructive ? .red : .orange
                )

                HStack(spacing: 12) {
                    Button("Cancel", role: .cancel) {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)

                    Button(confirmButtonTitle, role: action.role) {
                        onConfirm()
                        action.action()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(action.role == .destructive ? .red : .accentColor)
                    .disabled(!canConfirm)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
            .navigationTitle("Confirm Action")
        }
        .interactiveDismissDisabled(!canConfirm)
        .task {
            await runCountdown()
        }
    }

    private var totalDelay: Double {
        Double(max(delaySeconds, 1))
    }

    private var confirmButtonTitle: String {
        guard remainingSeconds > 0 else {
            return action.title
        }
        return "\(action.title) (\(remainingSeconds))"
    }

    private func runCountdown() async {
        visualProgress = 0
        remainingSeconds = Int(totalDelay)
        canConfirm = false

        await Task.yield()

        if reduceMotion {
            visualProgress = 1
        } else {
            withAnimation(.linear(duration: totalDelay)) {
                visualProgress = 1
            }
        }

        while remainingSeconds > 0 {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
            remainingSeconds -= 1
        }

        canConfirm = true
    }
}

private struct SmoothCountdownProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.18))

                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Confirmation countdown progress")
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100)) percent")
    }
}

extension View {
    func countdownConfirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String,
        actionTitle: String,
        role: ButtonRole? = .destructive,
        delaySeconds: Int = 3,
        onCancel: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        modifier(
            CountdownConfirmationDialogModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                action: CountdownConfirmationAction(
                    title: actionTitle,
                    role: role,
                    action: action
                ),
                delaySeconds: delaySeconds,
                onCancel: onCancel
            )
        )
    }
}
