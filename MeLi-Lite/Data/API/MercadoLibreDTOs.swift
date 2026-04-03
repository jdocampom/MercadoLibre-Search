import Foundation

struct MercadoSearchResponseDTO: Decodable, Sendable {
    let results: [MercadoItemDTO]
}

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

    private var mappedAttributes: [ProductAttribute] {
        (attributes ?? []).compactMap(\.model)
    }

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

struct MercadoPictureDTO: Decodable, Sendable {
    let url: String?
    let secureUrl: String?
}

struct MercadoShippingDTO: Decodable, Sendable {
    let freeShipping: Bool?
    let storePickup: Bool?

    var model: ShippingInfo {
        ShippingInfo(
            isFreeShipping: freeShipping ?? false,
            isStorePickupAvailable: storePickup ?? false
        )
    }
}

struct MercadoAttributeDTO: Decodable, Sendable {
    let id: String
    let name: String
    let valueName: String?

    var model: ProductAttribute? {
        guard let valueName, !valueName.isEmpty else {
            return nil
        }

        return ProductAttribute(id: id, name: name, value: valueName)
    }
}
