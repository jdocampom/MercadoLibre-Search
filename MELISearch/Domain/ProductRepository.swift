import Foundation

/// Repository wrapper that injects search and detail behaviors into the UI layer.
struct ProductRepository {
    /// Searches products using the active data source implementation with paging support.
    let search: (_ query: String, _ offset: Int, _ limit: Int) async throws -> ProductSearchPage
    /// Loads full product details for a selected identifier.
    let detail: (String) async throws -> ProductDetail

    /// Executes a paged product search against the active repository implementation.
    /// - Parameters:
    ///   - query: Search text entered by the user.
    ///   - offset: Zero-based offset of the first item requested for the page.
    ///   - limit: Maximum number of items requested for the page.
    /// - Returns: Page of product summaries plus backend paging metadata.
    func searchProducts(matching query: String, offset: Int, limit: Int) async throws -> ProductSearchPage {
        try await search(query, offset, limit)
    }

    /// Fetches the complete product payload for a selected item.
    /// - Parameter id: Mercado Libre item identifier.
    /// - Returns: Full product detail for the requested item.
    func fetchProductDetail(id: String) async throws -> ProductDetail {
        try await detail(id)
    }
}
