import SwiftUI

struct StatusPill: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quinary, in: .rect(cornerRadius: 16))
    }
}

@ViewBuilder
func runtimeBadge(title: String, tint: Color) -> some View {
    Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
    .lineLimit(1)
    .minimumScaleFactor(0.75)
    .truncationMode(.tail)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
}
