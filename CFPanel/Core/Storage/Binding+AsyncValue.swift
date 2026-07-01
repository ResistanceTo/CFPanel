import SwiftUI

extension Binding where Value: Sendable {
    static func asyncValue(
        get: @escaping @MainActor () -> Value,
        set: @escaping @MainActor (Value) async -> Void
    ) -> Binding<Value> {
        Binding(
            get: {
                MainActor.assumeIsolated {
                    get()
                }
            },
            set: { newValue in
                Task { @MainActor in
                    await set(newValue)
                }
            }
        )
    }
}
