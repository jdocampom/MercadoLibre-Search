import Foundation

/// Top-level search response returned by Mercado Libre.
struct MercadoSearchResponseDTO: Decodable, Sendable {
    /// Raw search result items returned by the backend.
    let results: [MercadoItemDTO]
}

/// Raw Mercado Libre item payload reused by both search and detail responses.
struct MercadoItemDTO: Decodable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let price: Double?
    let currencyId: String?
    let thumbnail: String?
    let permalink: String?
    let condition: String?
    let availableQuantity: Int?
    let soldQuantity: Int?
    let warranty: String?
    let shipping: MercadoShippingDTO?
    let attributes: [MercadoAttributeDTO]?
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
    let url: String?
    let secureUrl: String?
}

/// Raw shipping payload attached to a Mercado Libre item.
struct MercadoShippingDTO: Decodable, Sendable {
    let freeShipping: Bool?
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
    let id: String
    let name: String
    let valueName: String?

    /// Ignores empty attribute values before exposing them to the UI layer.
    var model: ProductAttribute? {
        guard let valueName, !valueName.isEmpty else {
            return nil
        }

        return ProductAttribute(id: id, name: name, value: valueName)
    }
}
