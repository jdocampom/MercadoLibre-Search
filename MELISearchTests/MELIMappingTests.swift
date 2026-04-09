import Foundation
import Testing
@testable import MELISearch

struct MELIMappingTests {
    @Test
    func productSearchPayloadMapsToSummary() throws {
        let payload = """
        {
          "id": "MCO-PRODUCT-123",
          "name": "Demo Phone",
          "family_name": "Demo Family",
          "permalink": "https://example.com/product",
          "buy_box_winner": {
            "price": 999.99,
            "currency_id": "COP",
            "condition": "new",
            "available_quantity": 3,
            "sold_quantity": 9,
            "shipping": {
              "free_shipping": true,
              "store_pickup": false
            }
          },
          "attributes": [
            {
              "id": "BRAND",
              "name": "Brand",
              "value_name": "Apple"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let product = try decoder.decode(MercadoProductSearchResultDTO.self, from: Data(payload.utf8))

        #expect(product.summary.id == "MCO-PRODUCT-123")
        #expect(product.summary.title == "Demo Phone")
        #expect(product.summary.subtitle == "Demo Family")
        #expect(product.summary.shipping.isFreeShipping)
        #expect(product.summary.attributes.first?.value == "Apple")
    }

    @Test
    func productDetailPayloadMapsToDetail() throws {
        let payload = """
        {
          "id": "MCO-PRODUCT-123",
          "name": "Demo Phone",
          "family_name": "Demo Family",
          "permalink": "https://example.com/product",
          "sold_quantity": 10,
          "pictures": [
            {
              "secure_url": "https://example.com/image.png"
            }
          ],
          "short_description": {
            "content": "Long description"
          },
          "buy_box_winner": {
            "price": 1299.99,
            "currency_id": "COP",
            "condition": "new",
            "available_quantity": 5,
            "sold_quantity": 8,
            "warranty": "12 meses",
            "shipping": {
              "free_shipping": true,
              "store_pickup": false
            }
          },
          "attributes": [
            {
              "id": "BRAND",
              "name": "Brand",
              "value_name": "Apple"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let product = try decoder.decode(MercadoProductDTO.self, from: Data(payload.utf8))

        #expect(product.detail.id == "MCO-PRODUCT-123")
        #expect(product.detail.title == "Demo Phone")
        #expect(product.detail.price == 1_299.99)
        #expect(product.detail.currencyCode == "COP")
        #expect(product.detail.imageURLs.count == 1)
        #expect(product.detail.shipping.isFreeShipping)
        #expect(product.detail.description == "Long description")
    }
}
