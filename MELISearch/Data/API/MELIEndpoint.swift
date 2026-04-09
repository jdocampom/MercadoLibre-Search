import Foundation

/// Mercado Libre endpoints supported by the application.
enum MELIEndpoint {
    /// Search endpoint scoped to a specific Mercado Libre site.
    case search(query: String, siteID: String)
    /// Item detail endpoint for a selected listing identifier.
    case itemDetail(id: String)

    /// Indicates whether the endpoint should be called without a bearer token by default.
    var prefersAnonymousAccess: Bool {
        switch self {
        case .search, .itemDetail:
            return false
        }
    }

    /// Indicates whether the endpoint is part of Mercado Libre's public catalog surface.
    var allowsAnonymousAccess: Bool {
        switch self {
        case .search, .itemDetail:
            return false
        }
    }

    /// Builds an authorized JSON request for the selected endpoint.
    /// - Parameter accessToken: Bearer token used to authorize the request.
    /// - Returns: A configured request ready for `URLSession`.
    func makeRequest(accessToken: String?) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.mercadolibre.com"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    /// Path component associated with the selected endpoint.
    private var path: String {
        switch self {
        case let .search(_, siteID):
            return "/sites/\(siteID)/search"
        case let .itemDetail(id):
            return "/items/\(id)"
        }
    }

    /// Query items required by the selected endpoint.
    private var queryItems: [URLQueryItem] {
        switch self {
        case let .search(query, _):
            return [URLQueryItem(name: "q", value: query)]
        case .itemDetail:
            return []
        }
    }
}
