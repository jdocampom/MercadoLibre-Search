import Foundation
import OSLog

/// Thin API client responsible for authenticated Mercado Libre requests and response mapping.
final class MELIAPIClient {
    /// Runtime configuration used to resolve credentials and site scope.
    private let configuration: AppConfiguration
    /// Async provider that resolves a valid bearer token before each live request.
    private let accessTokenProvider: @MainActor () async throws -> String
    /// Async provider that resolves the site scope for live searches.
    private let searchSiteIDProvider: @MainActor () async -> String
    /// Session used to execute Mercado Libre API requests.
    private let urlSession: URLSession
    /// In-memory cache that avoids refetching detail screens during the same session.
    private var detailCache: [String: ProductDetail] = [:]

    /// Creates a client bound to a specific runtime configuration.
    /// - Parameters:
    ///   - configuration: Runtime settings that provide site scope and credentials.
    ///   - accessTokenProvider: Async provider that returns a valid bearer token.
    ///   - searchSiteIDProvider: Async provider that resolves the best site scope for searches.
    init(
        configuration: AppConfiguration,
        accessTokenProvider: @escaping @MainActor () async throws -> String,
        searchSiteIDProvider: @escaping @MainActor () async -> String,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.accessTokenProvider = accessTokenProvider
        self.searchSiteIDProvider = searchSiteIDProvider
        self.urlSession = urlSession
    }

    /// Executes a search request and maps the response into summary models.
    /// - Parameter query: Search text to forward to Mercado Libre.
    /// - Returns: Product summaries returned by the search endpoint.
    func searchProducts(matching query: String) async throws -> [ProductSummary] {
        let siteID = await searchSiteIDProvider()
        let payload: MercadoSearchResponseDTO = try await request(
            endpoint: .search(query: query, siteID: siteID)
        )

        return payload.results.map(\.summary)
    }

    /// Loads a product detail response, serving cached values when available.
    /// - Parameter id: Mercado Libre item identifier.
    /// - Returns: Full product detail for the requested item.
    func fetchProductDetail(id: String) async throws -> ProductDetail {
        if let cachedDetail = detailCache[id] {
            return cachedDetail
        }

        let payload: MercadoItemDTO = try await request(endpoint: .itemDetail(id: id))

        let detail = payload.detail
        detailCache[id] = detail
        return detail
    }

    /// Sends an authorized request and translates transport or decoding failures into `AppError`.
    /// - Parameter endpoint: API endpoint to request.
    /// - Returns: A decoded payload of the expected type.
    private func request<T: Decodable>(endpoint: MELIEndpoint) async throws -> T {
        if endpoint.prefersAnonymousAccess {
            return try await performAnonymousRequest(endpoint: endpoint)
        }

        let preferredAccessToken: String

        do {
            preferredAccessToken = try await accessTokenProvider()
        } catch {
            let appError = AppError.from(error)
            if endpoint.allowsAnonymousAccess, appError == .missingAccessToken {
                AppLogger.networking.info(
                    "No bearer token available for public Mercado Libre endpoint. Retrying anonymously."
                )
                return try await performAnonymousRequest(endpoint: endpoint)
            }

            throw appError
        }

        if endpoint.requiresUserAccessToken, !preferredAccessToken.isMercadoLibreUserAccessToken {
            let appError = AppError.invalidUserAccessToken
            AppLogger.networking.error("\(appError.developerDescription)")
            throw appError
        }

        return try await performAuthorizedRequest(
            endpoint: endpoint,
            accessToken: preferredAccessToken,
            allowsAnonymousRetry: endpoint.allowsAnonymousAccess
        )
    }

    /// Executes a request without attaching an Authorization header.
    /// - Parameter endpoint: API endpoint to request.
    /// - Returns: A decoded payload of the expected type.
    private func performAnonymousRequest<T: Decodable>(endpoint: MELIEndpoint) async throws -> T {
        try await performRequest(endpoint: endpoint, accessToken: nil)
    }

    /// Executes a request with a guaranteed bearer token.
    /// - Parameters:
    ///   - endpoint: API endpoint to request.
    ///   - accessToken: Non-empty bearer token to attach to the request.
    ///   - allowsAnonymousRetry: Indicates whether a 403 should trigger one anonymous retry.
    /// - Returns: A decoded payload of the expected type.
    private func performAuthorizedRequest<T: Decodable>(
        endpoint: MELIEndpoint,
        accessToken: String,
        allowsAnonymousRetry: Bool = false
    ) async throws -> T {
        try await performRequest(
            endpoint: endpoint,
            accessToken: accessToken,
            allowsAnonymousRetry: allowsAnonymousRetry
        )
    }

    /// Executes the underlying HTTP request and optionally retries public catalog resources without auth.
    /// - Parameters:
    ///   - endpoint: API endpoint to request.
    ///   - accessToken: Bearer token to attach when available.
    ///   - allowsAnonymousRetry: Indicates whether a 403 should trigger one anonymous retry.
    /// - Returns: A decoded payload of the expected type.
    private func performRequest<T: Decodable>(
        endpoint: MELIEndpoint,
        accessToken: String?,
        allowsAnonymousRetry: Bool = false
    ) async throws -> T {
        let request = try endpoint.makeRequest(accessToken: accessToken)
        AppLogger.networking.debug("Requesting \(request.url?.absoluteString ?? "unknown")")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            guard 200 ..< 300 ~= httpResponse.statusCode else {
                if httpResponse.statusCode == 403, allowsAnonymousRetry, accessToken != nil {
                    AppLogger.networking.info(
                        "Public Mercado Libre catalog endpoint returned 403 with bearer token. Retrying without Authorization header."
                    )
                    return try await performRequest(endpoint: endpoint, accessToken: nil, allowsAnonymousRetry: false)
                }

                let mappedError = mapStatusCode(httpResponse.statusCode)
                let responseBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
                AppLogger.networking.error(
                    "HTTP failure: \(mappedError.developerDescription). Response body: \(responseBody, privacy: .public)"
                )
                throw mappedError
            }

            // Mercado Libre uses snake_case field names, so decoding is normalized here.
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch let appError as AppError {
            throw appError
        } catch let decodingError as DecodingError {
            let appError = AppError.decoding(decodingError.localizedDescription)
            AppLogger.networking.error("\(appError.developerDescription)")
            throw appError
        } catch let urlError as URLError {
            let appError = AppError.transport(urlError.code)
            AppLogger.networking.error("\(appError.developerDescription)")
            throw appError
        } catch {
            let appError = AppError.unknown(error.localizedDescription)
            AppLogger.networking.error("\(appError.developerDescription)")
            throw appError
        }
    }

    /// Converts HTTP status codes into domain-specific errors for the UI layer.
    /// - Parameter statusCode: HTTP status code received from Mercado Libre.
    /// - Returns: The domain error that best represents the HTTP failure.
    private func mapStatusCode(_ statusCode: Int) -> AppError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        default:
            return .httpStatus(statusCode)
        }
    }
}

private extension String {
    /// Mercado Libre user tokens produced by the Authorization Code flow start with `APP_USR-`.
    var isMercadoLibreUserAccessToken: Bool {
        hasPrefix("APP_USR-")
    }
}
