import Foundation

/// Factory for the production repository backed by the Mercado Libre API client.
enum LiveProductRepository {
    /// Creates a repository that forwards search and detail requests to the live API.
    /// - Parameter configuration: Runtime settings used to configure the API client.
    /// - Returns: A repository backed by live Mercado Libre requests.
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
