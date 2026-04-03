import Foundation

struct ProductRepository {
    let search: (String) async throws -> [ProductSummary]
    let detail: (String) async throws -> ProductDetail

    func searchProducts(matching query: String) async throws -> [ProductSummary] {
        try await search(query)
    }

    func fetchProductDetail(id: String) async throws -> ProductDetail {
        try await detail(id)
    }
}
