import Foundation
import Testing
@testable import MeLi_Lite

struct MercadoLibreMappingTests {
    @Test
    func itemPayloadMapsToSummary() throws {
        let payload = """
        {
          "id": "MCO123",
          "title": "Demo Phone",
          "subtitle": "Search payload",
          "price": 999.99,
          "currency_id": "ARS",
          "thumbnail": "https://example.com/thumb.png",
          "permalink": "https://example.com/item",
          "condition": "new",
          "available_quantity": 3,
          "sold_quantity": 9,
          "shipping": {
            "free_shipping": true,
            "store_pickup": false
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

        let item = try decoder.decode(MercadoItemDTO.self, from: Data(payload.utf8))

        #expect(item.summary.id == "MCO123")
        #expect(item.summary.title == "Demo Phone")
        #expect(item.summary.shipping.isFreeShipping)
        #expect(item.summary.attributes.first?.value == "Apple")
    }
}
