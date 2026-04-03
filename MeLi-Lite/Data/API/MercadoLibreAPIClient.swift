import Foundation
import OSLog

final class MercadoLibreAPIClient {
    private let configuration: AppConfiguration
    private var detailCache: [String: ProductDetail] = [:]

    init(configuration: AppConfiguration) {
        self.configuration = configuration
    }

    func searchProducts(matching query: String) async throws -> [ProductSummary] {
        let accessToken = try validatedAccessToken()
        let payload: MercadoSearchResponseDTO = try await request(
            endpoint: .search(query: query, siteID: configuration.siteID),
            accessToken: accessToken
        )

        return payload.results.map(\.summary)
    }

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

    private func validatedAccessToken() throws -> String {
        guard let accessToken = configuration.accessToken else {
            throw AppError.missingAccessToken
        }

        return accessToken
    }

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
                AppLogger.networking.error("HTTP failure: \(mappedError.developerDescription)")
                throw mappedError
            }

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
