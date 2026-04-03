import Foundation

enum LiveProductRepository {
    static func makeRepository(configuration: AppConfiguration) -> ProductRepository {
        let client = MercadoLibreAPIClient(configuration: configuration)

        return ProductRepository(
            search: { query in
                try await client.searchProducts(matching: query)
            },
            detail: { id in
                try await client.fetchProductDetail(id: id)
            }
        )
    }
}
