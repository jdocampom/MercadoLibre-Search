import Foundation

/// Factory for the production repository backed by the Mercado Libre API client.
enum LiveProductRepository {
    /// Creates a repository that forwards search and detail requests to the live API.
    /// - Parameters:
    ///   - configuration: Runtime settings used to configure the API client.
    ///   - accessTokenProvider: Async provider used to obtain a valid bearer token for each request.
    ///   - searchSiteIDProvider: Async provider used to resolve the best site for live searches.
    /// - Returns: A repository backed by live Mercado Libre requests.
    static func makeRepository(
        configuration: AppConfiguration,
        accessTokenProvider: @escaping @MainActor () async throws -> String,
        searchSiteIDProvider: @escaping @MainActor () async -> String
    ) -> ProductRepository {
        let client = MELIAPIClient(
            configuration: configuration,
            accessTokenProvider: accessTokenProvider,
            searchSiteIDProvider: searchSiteIDProvider
        )

        return ProductRepository(
            search: { query, offset, limit in
                try await client.searchProducts(matching: query, offset: offset, limit: limit)
            },
            detail: { id in
                try await client.fetchProductDetail(id: id)
            }
        )
    }
}
