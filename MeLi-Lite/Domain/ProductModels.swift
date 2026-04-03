import Foundation

struct ProductSummary: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let price: Double
    let currencyCode: String
    let thumbnailURL: URL?
    let permalinkURL: URL?
    let condition: String?
    let availableQuantity: Int?
    let soldQuantity: Int?
    let attributes: [ProductAttribute]
    let shipping: ShippingInfo
}

struct ProductDetail: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let price: Double
    let currencyCode: String
    let imageURLs: [URL]
    let permalinkURL: URL?
    let condition: String?
    let availableQuantity: Int?
    let soldQuantity: Int?
    let warranty: String?
    let attributes: [ProductAttribute]
    let shipping: ShippingInfo
    let description: String?
}

struct ProductAttribute: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let value: String
}

struct ShippingInfo: Hashable, Sendable {
    let isFreeShipping: Bool
    let isStorePickupAvailable: Bool

    static let unavailable = ShippingInfo(isFreeShipping: false, isStorePickupAvailable: false)
}
