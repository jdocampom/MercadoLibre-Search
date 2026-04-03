import Foundation

/// Lightweight product representation used by search results and navigation.
struct ProductSummary: Identifiable, Hashable, Sendable {
    /// Mercado Libre item identifier.
    let id: String
    /// Primary product name displayed in lists and titles.
    let title: String
    /// Secondary marketing copy shown when available.
    let subtitle: String?
    /// Current product price in the backend currency.
    let price: Double
    /// ISO currency code used to format the price.
    let currencyCode: String
    /// Representative thumbnail used in search results.
    let thumbnailURL: URL?
    /// Web URL that opens the product on Mercado Libre.
    let permalinkURL: URL?
    /// Raw product condition returned by the backend.
    let condition: String?
    /// Remaining stock reported by the backend.
    let availableQuantity: Int?
    /// Units already sold according to the listing.
    let soldQuantity: Int?
    /// Curated list of searchable product attributes.
    let attributes: [ProductAttribute]
    /// Delivery and pickup capabilities for the listing.
    let shipping: ShippingInfo
}

/// Full product representation used by the detail screen.
struct ProductDetail: Identifiable, Hashable, Sendable {
    /// Mercado Libre item identifier.
    let id: String
    /// Primary product name displayed in lists and titles.
    let title: String
    /// Secondary marketing copy shown when available.
    let subtitle: String?
    /// Current product price in the backend currency.
    let price: Double
    /// ISO currency code used to format the price.
    let currencyCode: String
    /// Gallery images rendered in the detail screen.
    let imageURLs: [URL]
    /// Web URL that opens the product on Mercado Libre.
    let permalinkURL: URL?
    /// Raw product condition returned by the backend.
    let condition: String?
    /// Remaining stock reported by the backend.
    let availableQuantity: Int?
    /// Units already sold according to the listing.
    let soldQuantity: Int?
    /// Warranty text returned by the API or demo fixtures.
    let warranty: String?
    /// Curated list of key product attributes.
    let attributes: [ProductAttribute]
    /// Delivery and pickup capabilities for the listing.
    let shipping: ShippingInfo
    /// Optional longer-form description used by the detail screen.
    let description: String?
}

/// Key-value attribute displayed in chips and fact grids.
struct ProductAttribute: Identifiable, Hashable, Sendable {
    /// Stable backend identifier for the attribute.
    let id: String
    /// Localized attribute label.
    let name: String
    /// Human-readable attribute value.
    let value: String
}

/// Shipping capabilities associated with a product listing.
struct ShippingInfo: Hashable, Sendable {
    /// Indicates whether the listing offers free delivery.
    let isFreeShipping: Bool
    /// Indicates whether the seller supports in-store pickup.
    let isStorePickupAvailable: Bool

    /// Fallback shipping state used when the backend omits shipping data.
    static let unavailable = ShippingInfo(isFreeShipping: false, isStorePickupAvailable: false)
}
