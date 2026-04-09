import Foundation

/// Mercado Libre endpoints supported by the application.
enum MELIEndpoint {
    /// Product search endpoint scoped to a specific Mercado Libre site.
    case productSearch(query: String, siteID: String)
    /// Product detail endpoint for a selected catalog identifier.
    case productDetail(id: String)

    /// Indicates whether the endpoint should be called without a bearer token by default.
    var prefersAnonymousAccess: Bool {
        switch self {
        case .productSearch, .productDetail:
            return false
        }
    }

    /// Indicates whether the endpoint is part of Mercado Libre's public catalog surface.
    var allowsAnonymousAccess: Bool {
        switch self {
        case .productSearch, .productDetail:
            return false
        }
    }

    /// Indicates whether the endpoint requires a user-scoped OAuth bearer token (`APP_USR-...`).
    var requiresUserAccessToken: Bool {
        switch self {
        case .productSearch, .productDetail:
            return true
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
        case .productSearch:
            return "/products/search"
        case let .productDetail(id):
            return "/products/\(id)"
        }
    }

    /// Query items required by the selected endpoint.
    private var queryItems: [URLQueryItem] {
        switch self {
        case let .productSearch(query, siteID):
            return [
                URLQueryItem(name: "status", value: "active"),
                URLQueryItem(name: "site_id", value: siteID),
                URLQueryItem(name: "q", value: query)
            ]
        case .productDetail:
            return []
        }
    }
}
