//
//  MeLi_LiteTests.swift
//  MeLi-LiteTests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import Foundation
import Testing
@testable import MeLi_Lite

@Suite("App Configuration")
struct AppConfigurationTests {
    @Test
    func defaultsToDemoWithoutLiveInputs() {
        let configuration = AppConfiguration.resolve(environment: [:])

        #expect(configuration.dataSource == .demo)
        #expect(configuration.siteID == "MCO")
        #expect(configuration.accessToken == nil)
    }

    @Test
    func explicitDemoWinsOverTokenPresence() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "demo",
            "MELI_ACCESS_TOKEN": "test-token",
            "MELI_SITE_ID": "MLA"
        ])

        #expect(configuration.dataSource == .demo)
        #expect(configuration.siteID == "MLA")
        #expect(configuration.accessToken == "test-token")
    }

    @Test
    func tokenStillEnablesLiveWhenSourceIsUnset() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_ACCESS_TOKEN": "test-token"
        ])

        #expect(configuration.dataSource == .live)
        #expect(configuration.siteID == "MCO")
    }

    @Test
    func resolvesOAuthConfigurationFromEnvironment() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_APP_ID": "123456",
            "MELI_CLIENT_SECRET": "secret",
            "MELI_REDIRECT_URL": "https://example.com/callback",
            "MELI_SITE_ID": "MCO"
        ])

        #expect(configuration.oauthConfiguration?.clientID == "123456")
        #expect(configuration.oauthConfiguration?.clientSecret == "secret")
        #expect(configuration.oauthConfiguration?.redirectURL.absoluteString == "https://example.com/callback")
        #expect(configuration.oauthConfiguration?.authorizationHost == "auth.mercadolibre.com.co")
    }

    @Test
    func overridingDataSourceKeepsOAuthAndSiteSettings() {
        let originalConfiguration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_APP_ID": "123456",
            "MELI_CLIENT_SECRET": "secret",
            "MELI_REDIRECT_URL": "https://example.com/callback",
            "MELI_AUTH_HOST": "auth.mercadolibre.com.co"
        ])

        let overriddenConfiguration = originalConfiguration.overriding(dataSource: .demo)

        #expect(overriddenConfiguration.dataSource == .demo)
        #expect(overriddenConfiguration.siteID == "MCO")
        #expect(overriddenConfiguration.oauthClientID == "123456")
        #expect(overriddenConfiguration.oauthClientSecret == "secret")
        #expect(overriddenConfiguration.oauthRedirectURL?.absoluteString == "https://example.com/callback")
        #expect(overriddenConfiguration.oauthAuthorizationHost == "auth.mercadolibre.com.co")
    }
}

@Suite("MELI OAuth")
struct MELIOAuthConfigurationTests {
    @Test
    func resolvesKnownAuthorizationHostForMCO() {
        #expect(MELIOAuthConfiguration.defaultAuthorizationHost(forSiteID: "MCO") == "auth.mercadolibre.com.co")
    }

    @Test
    func leavesUnknownSitesWithoutDefaultAuthorizationHost() {
        #expect(MELIOAuthConfiguration.defaultAuthorizationHost(forSiteID: "UNKNOWN") == nil)
    }
}

@MainActor
@Suite("MELI Authentication Session")
struct MELIAuthenticationSessionTests {
    @Test
    func rejectsRawAuthorizationCodeWithoutFullCallbackURL() async throws {
        let session = MELIAuthenticationSession(configuration: liveOAuthConfiguration())
        _ = try session.authorizationURL()

        let didAuthorize = await session.completeAuthorization(from: "raw-authorization-code")

        #expect(didAuthorize == false)
        #expect(session.latestError == .invalidAuthorizationCallback)
    }

    @Test
    func authorizationURLOmitsPKCEParameters() throws {
        let session = MELIAuthenticationSession(configuration: liveOAuthConfiguration())
        let authorizationURL = try session.authorizationURL()
        let components = try #require(URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false))
        let queryItemNames = Set((components.queryItems ?? []).map(\.name))

        #expect(queryItemNames.contains("response_type"))
        #expect(queryItemNames.contains("client_id"))
        #expect(queryItemNames.contains("redirect_uri"))
        #expect(queryItemNames.contains("state"))
        #expect(!queryItemNames.contains("code_challenge"))
        #expect(!queryItemNames.contains("code_challenge_method"))
    }

    @Test
    func rejectsCallbackThatDoesNotMatchRegisteredRedirect() async throws {
        let session = MELIAuthenticationSession(configuration: liveOAuthConfiguration())
        let authorizationURL = try session.authorizationURL()
        let components = try #require(URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false))
        let state = try #require(components.queryItems?.first(where: { $0.name == "state" })?.value)

        let didAuthorize = await session.completeAuthorization(
            from: "https://attacker.example/callback?code=test-code&state=\(state)"
        )

        #expect(didAuthorize == false)
        #expect(session.latestError == .invalidAuthorizationCallback)
    }

    @Test
    func completeAuthorizationCapturesUserIDFromTokenResponse() async throws {
        let configuration = liveOAuthConfiguration(clientID: "test-client-\(UUID().uuidString)")
        let session = MELIAuthenticationSession(
            configuration: configuration,
            urlSession: makeStubURLSession()
        )
        let authorizationURL = try session.authorizationURL()
        let components = try #require(URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false))
        let state = try #require(components.queryItems?.first(where: { $0.name == "state" })?.value)

        let didAuthorize = await session.completeAuthorization(
            from: "https://jdocampom.com/meli/callback?code=test-code&state=\(state)"
        )

        #expect(didAuthorize)
        #expect(session.currentUserID == 987654)
        #expect(session.status == .authenticated)

        session.signOut()
    }

    @Test
    func validateCurrentSessionUsesUsersMeEndpoint() async {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_ACCESS_TOKEN": "env-token"
        ])
        let session = MELIAuthenticationSession(
            configuration: configuration,
            urlSession: makeStubURLSession()
        )

        let didValidate = await session.validateCurrentSession()

        #expect(didValidate)
        #expect(session.currentUserID == 24680)
        #expect(session.sessionValidationTitle == "Session Confirmed")
        #expect(session.sessionValidationMessage.contains("24680"))
    }

    private func liveOAuthConfiguration(clientID: String = "123456") -> AppConfiguration {
        AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_APP_ID": clientID,
            "MELI_CLIENT_SECRET": "secret",
            "MELI_REDIRECT_URL": "https://jdocampom.com/meli/callback",
            "MELI_AUTH_HOST": "auth.mercadolibre.com.co"
        ])
    }

    private func makeStubURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubMercadoLibreURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class StubMercadoLibreURLProtocol: URLProtocol {
    nonisolated override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    nonisolated override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else {
            return false
        }

        return host == "api.mercadolibre.com"
    }

    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    nonisolated override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        switch url.path {
        case "/oauth/token":
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

            if body.contains("code_verifier=") {
                let response = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data("{\"error\":\"unexpected_code_verifier\"}".utf8))
                client?.urlProtocolDidFinishLoading(self)
                return
            }

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = Data("""
            {
              "access_token": "stub-access-token",
              "refresh_token": "stub-refresh-token",
              "expires_in": 3600,
              "scope": "read offline_access",
              "user_id": 987654
            }
            """.utf8)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case "/users/me":
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = Data("""
            {
              "id": 24680,
              "nickname": "john-doe",
              "site_id": "MCO"
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
