//
//  MeLi_LiteTests.swift
//  MeLi-LiteTests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import Foundation
import Testing
@testable import MELISearch

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
    func persistedOAuthConfigurationEnablesLiveWithoutEnvironmentVariables() {
        let configuration = AppConfiguration.resolve(
            environment: [:],
            persistedOAuthConfiguration: makePersistedOAuthConfiguration()
        )

        #expect(configuration.dataSource == .live)
        #expect(configuration.siteID == "MCO")
        #expect(configuration.oauthConfiguration?.clientID == "123456")
        #expect(configuration.oauthConfiguration?.clientSecret == "secret")
        #expect(configuration.oauthConfiguration?.redirectURL.absoluteString == "https://example.com/callback")
        #expect(configuration.oauthConfiguration?.authorizationHost == "auth.mercadolibre.com.co")
    }

    @Test
    func environmentOAuthValuesOverridePersistedOAuthConfiguration() {
        let configuration = AppConfiguration.resolve(
            environment: [
                "MELI_CLIENT_SECRET": "new-secret",
                "MELI_REDIRECT_URL": "https://example.com/new-callback"
            ],
            persistedOAuthConfiguration: makePersistedOAuthConfiguration()
        )

        #expect(configuration.dataSource == .live)
        #expect(configuration.oauthConfiguration?.clientID == "123456")
        #expect(configuration.oauthConfiguration?.clientSecret == "new-secret")
        #expect(configuration.oauthConfiguration?.redirectURL.absoluteString == "https://example.com/new-callback")
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

    @Test
    func explicitAuthorizationHostOverridesDefaultHost() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_APP_ID": "123456",
            "MELI_CLIENT_SECRET": "secret",
            "MELI_REDIRECT_URL": "https://example.com/callback",
            "MELI_AUTH_HOST": "auth.custom.example"
        ])

        #expect(configuration.oauthConfiguration?.authorizationHost == "auth.custom.example")
    }

    @Test
    func environmentBadgeReflectsSelectedDataSource() {
        let demoConfiguration = AppConfiguration.resolve(environment: [:])
        let liveConfiguration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_ACCESS_TOKEN": "token"
        ])

        #expect(demoConfiguration.environmentBadge == "Demo Catalog")
        #expect(liveConfiguration.environmentBadge == "Live API")
    }

    @Test
    func assistantNoteExplainsDemoMode() {
        let configuration = AppConfiguration.resolve(environment: [:])

        #expect(configuration.assistantNote.contains("Demo data is enabled by default"))
        #expect(configuration.assistantNote.contains("MELI_DATA_SOURCE=live"))
    }

    @Test
    func assistantNoteExplainsEnvironmentTokenMode() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_ACCESS_TOKEN": "token",
            "MELI_SITE_ID": "MLA"
        ])

        #expect(configuration.assistantNote.contains("using MELI_ACCESS_TOKEN"))
        #expect(configuration.assistantNote.contains("MLA"))
    }

    @Test
    func assistantNoteExplainsInteractiveOAuthMode() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_APP_ID": "123456",
            "MELI_CLIENT_SECRET": "secret",
            "MELI_REDIRECT_URL": "https://example.com/callback"
        ])

        #expect(configuration.assistantNote.contains("authorize interactively"))
        #expect(configuration.assistantNote.contains("MCO"))
    }

    @Test
    func assistantNoteExplainsIncompleteLiveOAuthConfiguration() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO"
        ])

        #expect(configuration.assistantNote.contains("OAuth is not fully configured yet"))
        #expect(configuration.assistantNote.contains("MCO"))
    }

    private func makePersistedOAuthConfiguration() -> AppConfiguration.PersistedOAuthConfiguration {
        AppConfiguration.PersistedOAuthConfiguration(
            siteID: "MCO",
            oauthClientID: "123456",
            oauthClientSecret: "secret",
            oauthRedirectURL: URL(string: "https://example.com/callback")!,
            oauthAuthorizationHost: "auth.mercadolibre.com.co"
        )
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
    func environmentTokenStartsInAuthenticatedEnvironmentState() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_ACCESS_TOKEN": "APP_USR-env-token"
        ])
        let session = MELIAuthenticationSession(configuration: configuration)

        #expect(session.status == .usingEnvironmentAccessToken)
        #expect(session.isAuthenticated)
        #expect(session.canValidateCurrentSession)
        #expect(session.statusMessage.contains("MELI_ACCESS_TOKEN"))
    }

    @Test
    func liveWithoutOAuthConfigurationStartsMissingConfiguration() {
        let session = MELIAuthenticationSession(
            configuration: AppConfiguration.resolve(environment: [
                "MELI_DATA_SOURCE": "live",
                "MELI_SITE_ID": "MCO"
            ])
        )

        #expect(session.status == .missingConfiguration)
        #expect(session.isAuthenticated == false)
        #expect(session.canAuthorizeInteractively == false)
    }

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
    func authorizationURLIncludesConfiguredRedirectAndGeneratedState() throws {
        let configuration = liveOAuthConfiguration()
        let session = MELIAuthenticationSession(configuration: configuration)
        let authorizationURL = try session.authorizationURL()
        let components = try #require(URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false))

        #expect(components.host == "auth.mercadolibre.com.co")
        #expect(components.path == "/authorization")
        #expect(components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value == "https://jdocampom.com/meli/callback")

        let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        #expect(returnedState?.isEmpty == false)
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
    func completeAuthorizationIfPossibleIgnoresUnrelatedIncomingURLs() async throws {
        let session = MELIAuthenticationSession(configuration: liveOAuthConfiguration())
        _ = try session.authorizationURL()

        let didAuthorize = await session.completeAuthorizationIfPossible(
            from: try #require(URL(string: "https://attacker.example/callback?code=test-code&state=test-state"))
        )

        #expect(didAuthorize == false)
        #expect(session.status == .authorizing)
        #expect(session.latestError == nil)
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
    func completeAuthorizationIfPossibleAcceptsRegisteredHTTPSCallback() async throws {
        let configuration = liveOAuthConfiguration(clientID: "test-client-\(UUID().uuidString)")
        let session = MELIAuthenticationSession(
            configuration: configuration,
            urlSession: makeStubURLSession()
        )
        let authorizationURL = try session.authorizationURL()
        let components = try #require(URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false))
        let state = try #require(components.queryItems?.first(where: { $0.name == "state" })?.value)

        let didAuthorize = await session.completeAuthorizationIfPossible(
            from: try #require(URL(string: "https://jdocampom.com/meli/callback?code=test-code&state=\(state)"))
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
            "MELI_ACCESS_TOKEN": "APP_USR-env-token"
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

    @Test
    func validateCurrentSessionReturnsFalseInDemoMode() async {
        let session = MELIAuthenticationSession(configuration: .preview)

        let didValidate = await session.validateCurrentSession()

        #expect(didValidate == false)
        #expect(session.sessionValidation == .idle)
        #expect(session.canValidateCurrentSession == false)
    }

    @Test
    func validateCurrentSessionForbiddenSurfacesFailureState() async {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_ACCESS_TOKEN": "APP_USR-forbidden-token"
        ])
        let session = MELIAuthenticationSession(
            configuration: configuration,
            urlSession: makeStubURLSession()
        )

        let didValidate = await session.validateCurrentSession()

        #expect(didValidate == false)
        #expect(session.latestError == .forbidden)
        #expect(session.sessionValidationTitle == "Session Validation Failed")
        #expect(session.sessionValidationMessage == AppError.forbidden.localizedDescription)
    }

    @Test
    func signOutResetsValidatedStateWhileKeepingEnvironmentMode() async {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "live",
            "MELI_SITE_ID": "MCO",
            "MELI_ACCESS_TOKEN": "APP_USR-env-token"
        ])
        let session = MELIAuthenticationSession(
            configuration: configuration,
            urlSession: makeStubURLSession()
        )

        _ = await session.validateCurrentSession()
        session.signOut()

        #expect(session.currentUserID == nil)
        #expect(session.sessionValidation == .idle)
        #expect(session.status == .usingEnvironmentAccessToken)
    }

    private func liveOAuthConfiguration(clientID: String = "test-client-\(UUID().uuidString)") -> AppConfiguration {
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
              "access_token": "APP_USR-stub-access-token",
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
            let authorizationValue = request.value(forHTTPHeaderField: "Authorization")
            let statusCode: Int
            let data: Data

            switch authorizationValue {
            case "Bearer APP_USR-forbidden-token":
                statusCode = 403
                data = Data("{\"message\":\"forbidden\",\"error\":\"forbidden\",\"status\":403,\"cause\":[]}".utf8)
            case nil:
                statusCode = 401
                data = Data("{\"message\":\"unauthorized\",\"error\":\"unauthorized\",\"status\":401,\"cause\":[]}".utf8)
            default:
                statusCode = 200
                data = Data("""
                {
                  "id": 24680,
                  "nickname": "john-doe",
                  "site_id": "MCO"
                }
                """.utf8)
            }

            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
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
