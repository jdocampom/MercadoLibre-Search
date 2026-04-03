import Foundation

/// Repository wrapper that injects search and detail behaviors into the UI layer.
struct ProductRepository {
    /// Searches products using the active data source implementation.
    let search: (String) async throws -> [ProductSummary]
    /// Loads full product details for a selected identifier.
    let detail: (String) async throws -> ProductDetail

    /// Executes a product search against the active repository implementation.
    /// - Parameter query: Search text entered by the user.
    /// - Returns: Product summaries that match the provided query.
    func searchProducts(matching query: String) async throws -> [ProductSummary] {
        try await search(query)
    }

    /// Fetches the complete product payload for a selected item.
    /// - Parameter id: Mercado Libre item identifier.
    /// - Returns: Full product detail for the requested item.
    func fetchProductDetail(id: String) async throws -> ProductDetail {
        try await detail(id)
    }
}
