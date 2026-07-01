import SwiftUI

enum ProductSurfaceStyle {
    static let cornerRadius: CGFloat = 24
    static let compactCornerRadius: CGFloat = 18
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 20
}

private struct ProductCardModifier: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(ProductSurfaceStyle.cardPadding)
            .background(backgroundStyle, in: .rect(cornerRadius: ProductSurfaceStyle.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: ProductSurfaceStyle.cornerRadius, style: .continuous)
                    .strokeBorder(borderStyle, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 16, y: 8)
    }

    private var backgroundStyle: some ShapeStyle {
        if let tint {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        tint.opacity(0.16),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(Color(.secondarySystemBackground))
    }

    private var borderStyle: some ShapeStyle {
        if let tint {
            return AnyShapeStyle(tint.opacity(0.18))
        }

        return AnyShapeStyle(Color.primary.opacity(0.05))
    }
}

extension View {
    func productCard(tint: Color? = nil) -> some View {
        modifier(ProductCardModifier(tint: tint))
    }
}
