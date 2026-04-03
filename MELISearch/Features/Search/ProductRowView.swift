import SwiftUI

/// Card-style row used to render a product inside the search result list.
struct ProductRowView: View {
    /// Product summary displayed by the row.
    let product: ProductSummary

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            thumbnail

            VStack(alignment: .leading, spacing: 10) {
                Text(product.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let subtitle = product.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(product.price.formatted(.currency(code: product.currencyCode)))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.11, green: 0.30, blue: 0.62))

                chips
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
    }
}

private extension ProductRowView {
    var thumbnail: some View {
        AsyncImage(url: product.thumbnailURL) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.91, blue: 0.65),
                            Color(red: 0.82, green: 0.90, blue: 0.99)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    var chips: some View {
        HStack(spacing: 8) {
            if product.shipping.isFreeShipping {
                chip("Free shipping", systemImage: "truck.box")
            }

            if let condition = product.condition {
                chip(condition.capitalized, systemImage: "tag")
            }
        }
    }

    /// Builds a reusable capsule chip for secondary product metadata.
    /// - Parameters:
    ///   - title: Localized chip title shown to the user.
    ///   - systemImage: SF Symbol name rendered next to the title.
    /// - Returns: A styled metadata chip used by the product row.
    func chip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.05), in: Capsule())
    }
}
