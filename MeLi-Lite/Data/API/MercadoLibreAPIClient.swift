import Foundation
import OSLog

/// Thin API client responsible for authenticated Mercado Libre requests and response mapping.
final class MercadoLibreAPIClient {
    /// Runtime configuration used to resolve credentials and site scope.
    private let configuration: AppConfiguration
    /// In-memory cache that avoids refetching detail screens during the same session.
    private var detailCache: [String: ProductDetail] = [:]

    /// Creates a client bound to a specific runtime configuration.
    /// - Parameter configuration: Runtime settings that provide site scope and credentials.
    init(configuration: AppConfiguration) {
        self.configuration = configuration
    }

    /// Executes a search request and maps the response into summary models.
    /// - Parameter query: Search text to forward to Mercado Libre.
    /// - Returns: Product summaries returned by the search endpoint.
    func searchProducts(matching query: String) async throws -> [ProductSummary] {
        let accessToken = try validatedAccessToken()
        let payload: MercadoSearchResponseDTO = try await request(
            endpoint: .search(query: query, siteID: configuration.siteID),
            accessToken: accessToken
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

        let accessToken = try validatedAccessToken()
        let payload: MercadoItemDTO = try await request(
            endpoint: .itemDetail(id: id),
            accessToken: accessToken
        )

        let detail = payload.detail
        detailCache[id] = detail
        return detail
    }

    /// Ensures live requests always have a non-empty access token available.
    /// - Returns: The configured Mercado Libre access token.
    private func validatedAccessToken() throws -> String {
        guard let accessToken = configuration.accessToken else {
            throw AppError.missingAccessToken
        }

        return accessToken
    }

    /// Sends an authorized request and translates transport or decoding failures into `AppError`.
    /// - Parameters:
    ///   - endpoint: API endpoint to request.
    ///   - accessToken: Bearer token used to authorize the request.
    /// - Returns: A decoded payload of the expected type.
    private func request<T: Decodable>(
        endpoint: MercadoLibreEndpoint,
        accessToken: String
    ) async throws -> T {
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
