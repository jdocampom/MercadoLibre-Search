import Foundation
import OSLog

/// Thin API client responsible for authenticated Mercado Libre requests and response mapping.
final class MELIAPIClient {
    /// Runtime configuration used to resolve credentials and site scope.
    private let configuration: AppConfiguration
    /// Async provider that resolves a valid bearer token before each live request.
    private let accessTokenProvider: @MainActor () async throws -> String
    /// In-memory cache that avoids refetching detail screens during the same session.
    private var detailCache: [String: ProductDetail] = [:]

    /// Creates a client bound to a specific runtime configuration.
    /// - Parameters:
    ///   - configuration: Runtime settings that provide site scope and credentials.
    ///   - accessTokenProvider: Async provider that returns a valid bearer token.
    init(
        configuration: AppConfiguration,
        accessTokenProvider: @escaping @MainActor () async throws -> String
    ) {
        self.configuration = configuration
        self.accessTokenProvider = accessTokenProvider
    }

    /// Executes a search request and maps the response into summary models.
    /// - Parameter query: Search text to forward to Mercado Libre.
    /// - Returns: Product summaries returned by the search endpoint.
    func searchProducts(matching query: String) async throws -> [ProductSummary] {
        let payload: MercadoSearchResponseDTO = try await request(
            endpoint: .search(query: query, siteID: configuration.siteID)
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
        let accessToken = try await accessTokenProvider()
        let request = try endpoint.makeRequest(accessToken: accessToken)
        AppLogger.networking.debug("Requesting \(request.url?.absoluteString ?? "unknown")")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            guard 200 ..< 300 ~= httpResponse.statusCode else {
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
