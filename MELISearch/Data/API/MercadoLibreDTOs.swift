import Foundation

/// Top-level product search response returned by Mercado Libre.
struct MercadoProductSearchResponseDTO: Decodable, Sendable {
    /// Raw catalog products returned by the backend.
    let results: [MercadoProductSearchResultDTO]
    /// Paging metadata reported by the backend for the current search window.
    let paging: MercadoPagingDTO?
}

/// Paging metadata attached to a Mercado Libre search response.
struct MercadoPagingDTO: Decodable, Sendable {
    /// Total number of items available for the query across all pages.
    let total: Int?
    /// Zero-based offset of the first item in this page.
    let offset: Int?
    /// Maximum number of items the server returned for this page.
    let limit: Int?
}

/// Raw Mercado Libre catalog product payload returned by the search endpoint.
struct MercadoProductSearchResultDTO: Decodable, Sendable {
    /// Mercado Libre catalog product identifier.
    let id: String
    /// Primary catalog product name.
    let name: String
    /// Family-level product name returned by catalog endpoints.
    let familyName: String?
    /// Deep link to the catalog product page on Mercado Libre.
    let permalink: String?
    /// Searchable attributes returned by Mercado Libre.
    let attributes: [MercadoAttributeDTO]?
    /// Gallery images returned by catalog endpoints.
    let pictures: [MercadoPictureDTO]?
    /// Best marketplace listing currently attached to the catalog product.
    let buyBoxWinner: MercadoBuyBoxWinnerDTO?
    /// Fallback price range when there is no single winning marketplace listing.
    let buyBoxWinnerPriceRange: MercadoPriceRangeDTO?

    /// Maps a raw catalog product payload into the lightweight search result model.
    var summary: ProductSummary {
        ProductSummary(
            id: id,
            title: name,
            subtitle: normalizedSubtitle,
            price: resolvedPrice,
            currencyCode: resolvedCurrencyCode,
            thumbnailURL: imageURLs.first,
            permalinkURL: permalink.flatMap(URL.init(string:)),
            condition: buyBoxWinner?.condition,
            availableQuantity: buyBoxWinner?.availableQuantity,
            soldQuantity: buyBoxWinner?.soldQuantity,
            attributes: mappedAttributes,
            shipping: buyBoxWinner?.shipping?.model ?? .unavailable
        )
    }
}

/// Raw Mercado Libre catalog product payload returned by the product detail endpoint.
struct MercadoProductDTO: Decodable, Sendable {
    /// Mercado Libre catalog product identifier.
    let id: String
    /// Primary catalog product name.
    let name: String
    /// Family-level product name returned by catalog endpoints.
    let familyName: String?
    /// Deep link to the catalog product page on Mercado Libre.
    let permalink: String?
    /// Quantity sold across the catalog product when available.
    let soldQuantity: Int?
    /// Searchable attributes returned by Mercado Libre.
    let attributes: [MercadoAttributeDTO]?
    /// Gallery images returned by detail responses.
    let pictures: [MercadoPictureDTO]?
    /// Variant pickers that may contain fallback thumbnails.
    let pickers: [MercadoProductPickerDTO]?
    /// Best marketplace listing currently attached to the catalog product.
    let buyBoxWinner: MercadoBuyBoxWinnerDTO?
    /// Fallback price range when there is no single winning marketplace listing.
    let buyBoxWinnerPriceRange: MercadoPriceRangeDTO?
    /// Optional longer-form description returned by the catalog API.
    let shortDescription: MercadoShortDescriptionDTO?

    /// Maps a raw catalog product payload into the richer detail model used by the detail screen.
    var detail: ProductDetail {
        ProductDetail(
            id: id,
            title: name,
            subtitle: normalizedSubtitle,
            price: resolvedPrice,
            currencyCode: resolvedCurrencyCode,
            imageURLs: imageURLs,
            permalinkURL: permalink.flatMap(URL.init(string:)),
            condition: buyBoxWinner?.condition,
            availableQuantity: buyBoxWinner?.availableQuantity,
            soldQuantity: buyBoxWinner?.soldQuantity ?? soldQuantity,
            warranty: buyBoxWinner?.warranty,
            attributes: mappedAttributes,
            shipping: buyBoxWinner?.shipping?.model ?? .unavailable,
            description: shortDescription?.content?.nilIfEmpty
        )
    }
}

private protocol MercadoCatalogProductPayload {
    var familyName: String? { get }
    var attributes: [MercadoAttributeDTO]? { get }
    var pictures: [MercadoPictureDTO]? { get }
    var buyBoxWinner: MercadoBuyBoxWinnerDTO? { get }
    var buyBoxWinnerPriceRange: MercadoPriceRangeDTO? { get }
}

extension MercadoProductSearchResultDTO: MercadoCatalogProductPayload {}
extension MercadoProductDTO: MercadoCatalogProductPayload {}

private extension MercadoCatalogProductPayload {
    /// Drops empty attributes before exposing them to the UI layer.
    var mappedAttributes: [ProductAttribute] {
        (attributes ?? []).compactMap(\.model)
    }

    /// Secondary catalog family name used as a subtitle only when it adds information.
    var normalizedSubtitle: String? {
        familyName?.nilIfEmpty
    }

    /// Product price prefers the current winning listing and falls back to the minimum catalog range.
    var resolvedPrice: Double {
        buyBoxWinner?.price ?? buyBoxWinnerPriceRange?.min?.price ?? 0
    }

    /// Currency code associated with the resolved product price.
    var resolvedCurrencyCode: String {
        buyBoxWinner?.currencyId ?? buyBoxWinnerPriceRange?.min?.currencyId ?? "ARS"
    }

    /// Gallery URLs returned by the catalog product.
    var imageURLs: [URL] {
        (pictures ?? []).compactMap { picture in
            let rawValue = picture.secureUrl ?? picture.url ?? ""
            return URL(string: rawValue)
        }
    }
}

private extension MercadoProductDTO {
    /// Gallery URLs prefer the product gallery and then fall back to picker thumbnails.
    var imageURLs: [URL] {
        let galleryURLs = (pictures ?? []).compactMap { picture in
            let rawValue = picture.secureUrl ?? picture.url ?? ""
            return URL(string: rawValue)
        }

        if !galleryURLs.isEmpty {
            return galleryURLs
        }

        return (pickers ?? [])
            .flatMap(\.products)
            .compactMap { option in
                guard let thumbnail = option.thumbnail, !thumbnail.isEmpty else {
                    return nil
                }

                return URL(string: thumbnail)
            }
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

/// Raw winning listing attached to a catalog product.
struct MercadoBuyBoxWinnerDTO: Decodable, Sendable {
    /// Backing marketplace listing identifier when Mercado Libre exposes it.
    let itemId: String?
    /// Current listing price.
    let price: Double?
    /// Currency code used to interpret `price`.
    let currencyId: String?
    /// Quantity already sold according to the winning listing.
    let soldQuantity: Int?
    /// Quantity currently available to purchase.
    let availableQuantity: Int?
    /// Shipping capabilities attached to the winning listing.
    let shipping: MercadoShippingDTO?
    /// Warranty description returned by the winning listing.
    let warranty: String?
    /// Raw item condition from the winning listing.
    let condition: String?
}

/// Raw price range attached to a catalog product.
struct MercadoPriceRangeDTO: Decodable, Sendable {
    /// Minimum visible price range for the product.
    let min: MercadoPriceDTO?
    /// Maximum visible price range for the product.
    let max: MercadoPriceDTO?
}

/// Raw price point returned by Mercado Libre.
struct MercadoPriceDTO: Decodable, Sendable {
    /// Price value.
    let price: Double?
    /// ISO currency code.
    let currencyId: String?
}

/// Raw picker payload used as a thumbnail fallback for catalog products.
struct MercadoProductPickerDTO: Decodable, Sendable {
    /// Picker-specific product options.
    let products: [MercadoProductPickerOptionDTO]
}

/// Raw picker option payload returned by catalog products.
struct MercadoProductPickerOptionDTO: Decodable, Sendable {
    /// Thumbnail URL for the option when available.
    let thumbnail: String?
}

/// Optional long description returned by catalog products.
struct MercadoShortDescriptionDTO: Decodable, Sendable {
    /// Raw textual content.
    let content: String?
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

private extension String {
    /// Returns nil when the string is empty after trimming visible whitespace.
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
