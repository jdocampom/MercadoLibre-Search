import Foundation

enum MercadoLibreEndpoint {
    case search(query: String, siteID: String)
    case itemDetail(id: String)

    func makeRequest(accessToken: String) throws -> URLRequest {
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
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private var path: String {
        switch self {
        case let .search(_, siteID):
            return "/sites/\(siteID)/search"
        case let .itemDetail(id):
            return "/items/\(id)"
        }
    }

    private var queryItems: [URLQueryItem] {
        switch self {
        case let .search(query, _):
            return [URLQueryItem(name: "q", value: query)]
        case .itemDetail:
            return []
        }
    }
}
