import Foundation
import Testing
@testable import MELISearch

@Suite(.serialized)
struct MELIAPIClientTests {
    @Test
    func searchUsesBearerTokenForSearchEndpoint() async throws {
        PublicCatalogFallbackRequestRecorder.reset()

        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_ACCESS_TOKEN": "APP_USR-env-token"
        ])

        let client = MELIAPIClient(
            configuration: configuration,
            accessTokenProvider: { "APP_USR-env-token" },
            searchSiteIDProvider: { "MCO" },
            urlSession: makeStubURLSession()
        )

        let results = try await client.searchProducts(matching: "iPhone")

        #expect(results.count == 1)
        #expect(results.first?.id == "MCO-PRODUCT-123")
        #expect(results.first?.title == "iPhone de prueba")
        #expect(results.first?.price == 1_000)
        #expect(results.first?.currencyCode == "COP")
        #expect(PublicCatalogFallbackRequestRecorder.snapshot() == ["Bearer APP_USR-env-token"])
    }

    @Test
    func searchRejectsApplicationScopedAccessToken() async {
        PublicCatalogFallbackRequestRecorder.reset()

        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_ACCESS_TOKEN": "APP-application-token"
        ])

        let client = MELIAPIClient(
            configuration: configuration,
            accessTokenProvider: { "APP-application-token" },
            searchSiteIDProvider: { "MCO" },
            urlSession: makeStubURLSession()
        )

        do {
            _ = try await client.searchProducts(matching: "iPhone")
            Issue.record("Expected search to reject APP application tokens.")
        } catch {
            #expect(AppError.from(error) == .invalidUserAccessToken)
            #expect(PublicCatalogFallbackRequestRecorder.snapshot().isEmpty)
        }
    }

    @Test
    func searchUsesResolvedSiteIDFromProvider() async throws {
        PublicCatalogFallbackRequestRecorder.reset()

        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_ACCESS_TOKEN": "APP_USR-env-token"
        ])

        let client = MELIAPIClient(
            configuration: configuration,
            accessTokenProvider: { "APP_USR-env-token" },
            searchSiteIDProvider: { "MLA" },
            urlSession: makeStubURLSession()
        )

        let results = try await client.searchProducts(matching: "iPhone")

        #expect(results.count == 1)
        #expect(results.first?.id == "MLA-PRODUCT-123")
        #expect(results.first?.title == "iPhone de prueba en MLA")
        #expect(PublicCatalogFallbackRequestRecorder.snapshot() == ["Bearer APP_USR-env-token"])
    }

    @Test
    func fetchProductDetailUsesCatalogProductEndpoint() async throws {
        PublicCatalogFallbackRequestRecorder.reset()

        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_ACCESS_TOKEN": "APP_USR-env-token"
        ])

        let client = MELIAPIClient(
            configuration: configuration,
            accessTokenProvider: { "APP_USR-env-token" },
            searchSiteIDProvider: { "MCO" },
            urlSession: makeStubURLSession()
        )

        let detail = try await client.fetchProductDetail(id: "MCO-PRODUCT-123")

        #expect(detail.id == "MCO-PRODUCT-123")
        #expect(detail.title == "iPhone de prueba")
        #expect(detail.price == 1_200)
        #expect(detail.currencyCode == "COP")
        #expect(detail.shipping.isFreeShipping)
        #expect(detail.imageURLs.count == 1)
        #expect(PublicCatalogFallbackRequestRecorder.snapshot() == ["Bearer APP_USR-env-token"])
    }

    private func makeStubURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicCatalogFallbackURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private enum PublicCatalogFallbackRequestRecorder {
    nonisolated(unsafe) private static let lock = NSLock()
    nonisolated(unsafe) private static var authorizationHeaders: [String?] = []

    nonisolated static func reset() {
        lock.lock()
        defer { lock.unlock() }
        authorizationHeaders = []
    }

    nonisolated static func append(_ value: String?) {
        lock.lock()
        defer { lock.unlock() }
        authorizationHeaders.append(value)
    }

    nonisolated static func snapshot() -> [String?] {
        lock.lock()
        defer { lock.unlock() }
        return authorizationHeaders
    }
}

private final class PublicCatalogFallbackURLProtocol: URLProtocol {
    nonisolated override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    nonisolated override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.mercadolibre.com"
    }

    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    nonisolated override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        PublicCatalogFallbackRequestRecorder.append(request.value(forHTTPHeaderField: "Authorization"))

        switch url.path {
        case "/products/search" where url.query?.contains("site_id=MCO") == true:
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = Data("""
            {
              "results": [
                {
                  "id": "MCO-PRODUCT-123",
                  "name": "iPhone de prueba",
                  "family_name": "iPhone",
                  "attributes": [
                    {
                      "id": "BRAND",
                      "name": "Marca",
                      "value_name": "Apple"
                    }
                  ],
                  "buy_box_winner": {
                    "price": 1000,
                    "currency_id": "COP",
                    "sold_quantity": 7,
                    "available_quantity": 2,
                    "condition": "new",
                    "shipping": {
                      "free_shipping": true,
                      "store_pickup": false
                    }
                  }
                }
              ]
            }
            """.utf8)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case "/products/search" where url.query?.contains("site_id=MLA") == true:
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = Data("""
            {
              "results": [
                {
                  "id": "MLA-PRODUCT-123",
                  "name": "iPhone de prueba en MLA",
                  "family_name": "iPhone",
                  "buy_box_winner": {
                    "price": 2000,
                    "currency_id": "ARS",
                    "sold_quantity": 4,
                    "available_quantity": 1,
                    "condition": "new",
                    "shipping": {
                      "free_shipping": false,
                      "store_pickup": true
                    }
                  }
                }
              ]
            }
            """.utf8)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case "/products/MCO-PRODUCT-123":
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = Data("""
            {
              "id": "MCO-PRODUCT-123",
              "name": "iPhone de prueba",
              "family_name": "iPhone",
              "sold_quantity": 9,
              "permalink": "https://mercadolibre.com.co/p/MCO-PRODUCT-123",
              "pictures": [
                {
                  "secure_url": "https://http2.mlstatic.com/D_123.jpg"
                }
              ],
              "attributes": [
                {
                  "id": "BRAND",
                  "name": "Marca",
                  "value_name": "Apple"
                }
              ],
              "short_description": {
                "content": "Catalog detail"
              },
              "buy_box_winner": {
                "item_id": "MCOITEM123",
                "price": 1200,
                "currency_id": "COP",
                "sold_quantity": 8,
                "available_quantity": 3,
                "warranty": "12 meses",
                "condition": "new",
                "shipping": {
                  "free_shipping": true,
                  "store_pickup": false
                }
              }
            }
            """.utf8)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        default:
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    nonisolated override func stopLoading() {}
}
