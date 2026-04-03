import Foundation

/// Top-level search response returned by Mercado Libre.
struct MercadoSearchResponseDTO: Decodable, Sendable {
    /// Raw search result items returned by the backend.
    let results: [MercadoItemDTO]
}

/// Raw Mercado Libre item payload reused by both search and detail responses.
struct MercadoItemDTO: Decodable, Sendable {
    /// Mercado Libre item identifier.
    let id: String
    /// Primary listing title.
    let title: String
    /// Secondary marketing copy returned by some endpoints.
    let subtitle: String?
    /// Current listing price.
    let price: Double?
    /// Currency code used to interpret `price`.
    let currencyId: String?
    /// Thumbnail URL returned by search responses.
    let thumbnail: String?
    /// Deep link to the listing on Mercado Libre.
    let permalink: String?
    /// Raw item condition from the backend.
    let condition: String?
    /// Quantity currently available to purchase.
    let availableQuantity: Int?
    /// Quantity already sold according to the listing.
    let soldQuantity: Int?
    /// Warranty description returned by detail responses.
    let warranty: String?
    /// Shipping capabilities attached to the listing.
    let shipping: MercadoShippingDTO?
    /// Searchable attributes returned by Mercado Libre.
    let attributes: [MercadoAttributeDTO]?
    /// Gallery images returned by detail responses.
    let pictures: [MercadoPictureDTO]?

    /// Maps a raw item payload into the lightweight search result model.
    var summary: ProductSummary {
        ProductSummary(
            id: id,
            title: title,
            subtitle: subtitle,
            price: price ?? 0,
            currencyCode: currencyId ?? "ARS",
            thumbnailURL: galleryURLs.first,
            permalinkURL: permalink.flatMap(URL.init(string:)),
            condition: condition,
            availableQuantity: availableQuantity,
            soldQuantity: soldQuantity,
            attributes: mappedAttributes,
            shipping: shipping?.model ?? .unavailable
        )
    }

    /// Maps a raw item payload into the richer detail model used by the detail screen.
    var detail: ProductDetail {
        ProductDetail(
            id: id,
            title: title,
            subtitle: subtitle,
            price: price ?? 0,
            currencyCode: currencyId ?? "ARS",
            imageURLs: galleryURLs,
            permalinkURL: permalink.flatMap(URL.init(string:)),
            condition: condition,
            availableQuantity: availableQuantity,
            soldQuantity: soldQuantity,
            warranty: warranty,
            attributes: mappedAttributes,
            shipping: shipping?.model ?? .unavailable,
            description: nil
        )
    }

    /// Drops empty attributes before exposing them to the UI layer.
    private var mappedAttributes: [ProductAttribute] {
        (attributes ?? []).compactMap(\.model)
    }

    /// Prefers gallery URLs and falls back to the thumbnail when the API omits pictures.
    private var galleryURLs: [URL] {
        let pictureURLs = (pictures ?? []).compactMap { picture in
            let rawValue = picture.secureUrl ?? picture.url ?? ""
            return URL(string: rawValue)
        }

        if pictureURLs.isEmpty, let thumbnail, let thumbnailURL = URL(string: thumbnail) {
            return [thumbnailURL]
        }

        return pictureURLs
    }
}

/// Raw picture payload attached to a Mercado Libre item.
struct MercadoPictureDTO: Decodable, Sendable {
    /// Non-secure image URL when present.
    let url: String?
    /// HTTPS image URL when present.
    let secureUrl: String?
}

/// Raw shipping payload attached to a Mercado Libre item.
struct MercadoShippingDTO: Decodable, Sendable {
    /// Indicates whether the listing offers free delivery.
    let freeShipping: Bool?
    /// Indicates whether the seller supports in-store pickup.
    let storePickup: Bool?

    /// Converts the API shipping payload into the domain shipping model.
    var model: ShippingInfo {
        ShippingInfo(
            isFreeShipping: freeShipping ?? false,
            isStorePickupAvailable: storePickup ?? false
        )
    }
}

/// Raw attribute payload attached to a Mercado Libre item.
struct MercadoAttributeDTO: Decodable, Sendable {
    /// Stable attribute identifier returned by Mercado Libre.
    let id: String
    /// Human-readable attribute label.
    let name: String
    /// Human-readable attribute value.
    let valueName: String?

    /// Ignores empty attribute values before exposing them to the UI layer.
    var model: ProductAttribute? {
        guard let valueName, !valueName.isEmpty else {
            return nil
        }

        return ProductAttribute(id: id, name: name, value: valueName)
    }
}
