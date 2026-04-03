import Foundation

/// Factory for the production repository backed by the Mercado Libre API client.
enum LiveProductRepository {
    /// Creates a repository that forwards search and detail requests to the live API.
    /// - Parameters:
    ///   - configuration: Runtime settings used to configure the API client.
    ///   - accessTokenProvider: Async provider used to obtain a valid bearer token for each request.
    /// - Returns: A repository backed by live Mercado Libre requests.
    static func makeRepository(
        configuration: AppConfiguration,
        accessTokenProvider: @escaping @MainActor () async throws -> String
    ) -> ProductRepository {
        let client = MercadoLibreAPIClient(
            configuration: configuration,
            accessTokenProvider: accessTokenProvider
        )

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
