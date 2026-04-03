import Foundation

enum DemoProductRepository {
    static func makeRepository() -> ProductRepository {
        ProductRepository(
            search: { query in
                let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedQuery.isEmpty else {
                    return []
                }

                let loweredQuery = normalizedQuery.lowercased()
                return catalog
                    .filter { detail in
                        detail.title.lowercased().contains(loweredQuery) ||
                        detail.attributes.contains(where: { attribute in
                            attribute.name.lowercased().contains(loweredQuery) ||
                            attribute.value.lowercased().contains(loweredQuery)
                        })
                    }
                    .map(\.summary)
            },
            detail: { id in
                guard let product = catalog.first(where: { $0.id == id }) else {
                    throw AppError.unknown("Demo catalog item \(id) was not found.")
                }

                return product
            }
        )
    }

    private static let catalog: [ProductDetail] = [
        ProductDetail(
            id: "DEMO-IPHONE-15-PRO",
            title: "iPhone 15 Pro 256 GB Natural Titanium",
            subtitle: "Unlocked smartphone with ProMotion display",
            price: 1_699_999,
            currencyCode: "ARS",
            imageURLs: imageURLs(for: "iphone15"),
            permalinkURL: URL(string: "https://www.mercadolibre.com.ar"),
            condition: "new",
            availableQuantity: 12,
            soldQuantity: 238,
            warranty: "12-month official warranty",
            attributes: [
                ProductAttribute(id: "BRAND", name: "Brand", value: "Apple"),
                ProductAttribute(id: "STORAGE", name: "Storage", value: "256 GB"),
                ProductAttribute(id: "DISPLAY", name: "Display", value: "6.1-inch ProMotion"),
                ProductAttribute(id: "COLOR", name: "Color", value: "Natural Titanium")
            ],
            shipping: ShippingInfo(isFreeShipping: true, isStorePickupAvailable: true),
            description: "A premium smartphone demo item used to validate the end-to-end flow of search, results and detail in the challenge app."
        ),
        ProductDetail(
            id: "DEMO-SONY-WH1000XM5",
            title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones",
            subtitle: "Flagship over-ear headphones with adaptive ANC",
            price: 649_999,
            currencyCode: "ARS",
            imageURLs: imageURLs(for: "sonyxm5"),
            permalinkURL: URL(string: "https://www.mercadolibre.com.ar"),
            condition: "new",
            availableQuantity: 18,
            soldQuantity: 142,
            warranty: "6-month seller warranty",
            attributes: [
                ProductAttribute(id: "BRAND", name: "Brand", value: "Sony"),
                ProductAttribute(id: "COLOR", name: "Color", value: "Black"),
                ProductAttribute(id: "BATTERY", name: "Battery life", value: "30 hours"),
                ProductAttribute(id: "CONNECTIVITY", name: "Connectivity", value: "Bluetooth 5.2")
            ],
            shipping: ShippingInfo(isFreeShipping: true, isStorePickupAvailable: false),
            description: "Balanced sound, strong battery life and excellent comfort make this a useful detail screen example."
        ),
        ProductDetail(
            id: "DEMO-KINDLE-PAPERWHITE",
            title: "Kindle Paperwhite 11th Gen 16 GB",
            subtitle: "Compact e-reader with adjustable warm light",
            price: 329_990,
            currencyCode: "ARS",
            imageURLs: imageURLs(for: "kindlepaperwhite"),
            permalinkURL: URL(string: "https://www.mercadolibre.com.ar"),
            condition: "new",
            availableQuantity: 27,
            soldQuantity: 460,
            warranty: "12-month limited warranty",
            attributes: [
                ProductAttribute(id: "BRAND", name: "Brand", value: "Amazon"),
                ProductAttribute(id: "STORAGE", name: "Storage", value: "16 GB"),
                ProductAttribute(id: "DISPLAY", name: "Display", value: "6.8-inch glare-free"),
                ProductAttribute(id: "WATERPROOF", name: "Waterproof", value: "Yes")
            ],
            shipping: ShippingInfo(isFreeShipping: false, isStorePickupAvailable: true),
            description: "A lighter product example with concise attributes, ideal for validating empty states and scroll behavior."
        ),
        ProductDetail(
            id: "DEMO-GARMIN-FR255",
            title: "Garmin Forerunner 255 Music GPS Smartwatch",
            subtitle: "Performance watch for runners and triathletes",
            price: 899_500,
            currencyCode: "ARS",
            imageURLs: imageURLs(for: "garmin255"),
            permalinkURL: URL(string: "https://www.mercadolibre.com.ar"),
            condition: "new",
            availableQuantity: 8,
            soldQuantity: 79,
            warranty: "12-month official warranty",
            attributes: [
                ProductAttribute(id: "BRAND", name: "Brand", value: "Garmin"),
                ProductAttribute(id: "GPS", name: "GPS", value: "Multi-band"),
                ProductAttribute(id: "BATTERY", name: "Battery life", value: "Up to 14 days"),
                ProductAttribute(id: "FEATURE", name: "Main feature", value: "Offline music")
            ],
            shipping: ShippingInfo(isFreeShipping: true, isStorePickupAvailable: false),
            description: "This demo item covers the wearable category and expands the search fixtures beyond phones and audio."
        ),
        ProductDetail(
            id: "DEMO-JBL-CHARGE-5",
            title: "JBL Charge 5 Portable Bluetooth Speaker",
            subtitle: "Waterproof speaker with power bank feature",
            price: 279_999,
            currencyCode: "ARS",
            imageURLs: imageURLs(for: "jblcharge5"),
            permalinkURL: URL(string: "https://www.mercadolibre.com.ar"),
            condition: "new",
            availableQuantity: 33,
            soldQuantity: 331,
            warranty: "6-month limited warranty",
            attributes: [
                ProductAttribute(id: "BRAND", name: "Brand", value: "JBL"),
                ProductAttribute(id: "BATTERY", name: "Battery life", value: "20 hours"),
                ProductAttribute(id: "RESISTANCE", name: "Resistance", value: "IP67"),
                ProductAttribute(id: "COLOR", name: "Color", value: "Blue")
            ],
            shipping: ShippingInfo(isFreeShipping: false, isStorePickupAvailable: false),
            description: "A simple media-heavy sample used to test cards with long titles and attribute grids."
        )
    ]

    private static func imageURLs(for _: String) -> [URL] {
        // Demo mode must stay usable in CI, previews and sandboxed environments
        // where outbound DNS/network access may be blocked.
        []
    }
}

private extension ProductDetail {
    var summary: ProductSummary {
        ProductSummary(
            id: id,
            title: title,
            subtitle: subtitle,
            price: price,
            currencyCode: currencyCode,
            thumbnailURL: imageURLs.first,
            permalinkURL: permalinkURL,
            condition: condition,
            availableQuantity: availableQuantity,
            soldQuantity: soldQuantity,
            attributes: attributes,
            shipping: shipping
        )
    }
}
