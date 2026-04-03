import Foundation
import Observation
import OSLog

/// Manages Mercado Libre OAuth authorization, refresh, and persisted credentials for live API calls.
@Observable
@MainActor final class MELIAuthenticationSession {
    /// High-level authentication states exposed to the UI.
    enum Status: Equatable {
        /// The app is explicitly running with demo data only.
        case demoMode
        /// Live mode is active and the token comes directly from the process environment.
        case usingEnvironmentAccessToken
        /// Interactive OAuth cannot start because one or more required settings are missing.
        case missingConfiguration
        /// The app is ready to start an OAuth authorization-code flow.
        case signedOut
        /// The authorization URL has been generated and the browser can request user consent.
        case authorizing
        /// The app is exchanging an authorization code for tokens.
        case exchangingCode
        /// The app is refreshing a previously stored OAuth session.
        case refreshing
        /// A reusable live session is available for Mercado Libre requests.
        case authenticated
        /// The latest OAuth operation failed.
        case failed(AppError)
    }

    /// Outcome of an explicit `/users/me` check used to verify which account a bearer token belongs to.
    enum SessionValidation: Equatable {
        /// No diagnostic request has been made yet for the current live session.
        case idle
        /// The app is currently validating the resolved bearer token against `/users/me`.
        case validating
        /// Mercado Libre confirmed the active session and returned the current user.
        case validated(ValidatedUser)
        /// Mercado Libre rejected or failed the diagnostic request.
        case failed(AppError)
    }

    /// Minimal `/users/me` payload used to confirm the authenticated account behind the current token.
    struct ValidatedUser: Decodable, Equatable, Sendable {
        let id: Int
        let nickname: String?
        let siteID: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case nickname
            case siteID = "site_id"
        }
    }

    /// The application's configuration, providing access to OAuth parameters,
    /// environment flags (such as demo mode), and any preset access tokens.
    private let configuration: AppConfiguration
    
    /// The OAuth configuration for Mercado Libre if available, containing endpoints and credentials 
    /// necessary for performing the OAuth authorization code flow.
    private let oauthConfiguration: MELIOAuthConfiguration?
    
    /// A secure storage interface for saving, loading, and deleting persisted credentials related
    /// to Mercado Libre OAuth sessions.
    private let keychainStore: KeychainStore
    
    /// The URLSession instance used to perform network requests for OAuth flows
    /// and token exchanges.
    private let urlSession: URLSession

    /// The current state of the OAuth authentication session.
    private(set) var status: Status
    
    /// The Mercado Libre user ID currently associated with the active authentication
    /// session, if available.
    private(set) var currentUserID: Int?
    
    /// The most recent error encountered during an OAuth operation or authentication flow.
    private(set) var latestError: AppError?

    /// Latest explicit validation result for the current live session.
    private(set) var sessionValidation: SessionValidation = .idle

    @ObservationIgnored private var persistedCredentials: StoredCredentials?
    @ObservationIgnored private var pendingAuthorization: PendingAuthorization?
    @ObservationIgnored private var hasPrepared = false

    /// Creates a session coordinator for the current runtime configuration.
    /// - Parameters:
    ///   - configuration: Environment-derived settings that define demo/live behavior and OAuth inputs.
    ///   - urlSession: Session used to perform token exchange and refresh calls.
    init(
        configuration: AppConfiguration,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        oauthConfiguration = configuration.oauthConfiguration
        keychainStore = KeychainStore(
            service: "com.jdocampo.MeLi-Lite.mercadolibre.oauth",
            account: configuration.oauthClientID ?? "default"
        )
        self.urlSession = urlSession

        if configuration.isUsingDemoData {
            status = .demoMode
        } else if configuration.accessToken != nil {
            status = .usingEnvironmentAccessToken
        } else if oauthConfiguration == nil {
            status = .missingConfiguration
        } else {
            status = .signedOut
        }
    }

    /// Indicates whether the app has enough local configuration to start interactive OAuth.
    var canAuthorizeInteractively: Bool {
        oauthConfiguration != nil
    }

    /// Indicates whether the live-mode banner should suggest configuring or managing OAuth.
    var shouldShowAuthorizationBanner: Bool {
        !configuration.isUsingDemoData && configuration.accessToken == nil
    }

    /// Indicates whether the UI should proactively surface the OAuth sheet on first launch.
    var shouldPromptForAuthorization: Bool {
        status == .signedOut && canAuthorizeInteractively
    }

    /// Indicates whether live requests can proceed without another authorization step.
    var isAuthenticated: Bool {
        switch status {
        case .authenticated, .usingEnvironmentAccessToken:
            return true
        default:
            return false
        }
    }

    /// Indicates whether the current runtime has enough state to validate `/users/me`.
    var canValidateCurrentSession: Bool {
        !configuration.isUsingDemoData && isAuthenticated
    }

    /// Indicates whether an explicit `/users/me` validation request is in flight.
    var isValidatingCurrentSession: Bool {
        if case .validating = sessionValidation {
            return true
        }

        return false
    }

    /// Indicates whether the UI should surface the latest `/users/me` validation result.
    var shouldShowSessionValidationStatus: Bool {
        if case .idle = sessionValidation {
            return false
        }

        return true
    }

    /// Short status label rendered in banners and sheets.
    var statusTitle: String {
        switch status {
        case .demoMode:
            return "Demo Mode"
        case .usingEnvironmentAccessToken:
            return "Environment Token"
        case .missingConfiguration:
            return "OAuth Not Configured"
        case .signedOut:
            return "Live OAuth Required"
        case .authorizing:
            return "Authorization Started"
        case .exchangingCode:
            return "Exchanging Code"
        case .refreshing:
            return "Refreshing Session"
        case .authenticated:
            return "Live OAuth Ready"
        case .failed:
            return "Authorization Failed"
        }
    }

    /// Human-readable explanation of the current authentication state.
    var statusMessage: String {
        switch status {
        case .demoMode:
            return "The app is running with local fixtures only."
        case .usingEnvironmentAccessToken:
            return "Live requests use MELI_ACCESS_TOKEN from the process environment."
        case .missingConfiguration:
            return "Set MELI_APP_ID, MELI_CLIENT_SECRET, and MELI_REDIRECT_URL to complete the OAuth flow."
        case .signedOut:
            return "Open the Mercado Libre authorization page, then paste the full callback URL returned by the same authorization attempt."
        case .authorizing:
            return "The browser can now request access. After approving the app, come back and paste the full callback URL so the app can validate state."
        case .exchangingCode:
            return "The app is exchanging the authorization code for a live access token."
        case .refreshing:
            return "The stored refresh token is being used to renew the live session."
        case .authenticated:
            if let currentUserID {
                if let scope = persistedCredentials?.scope, !scope.isEmpty {
                    return "Live requests are authorized for Mercado Libre user \(currentUserID) with scope \(scope)."
                }

                return "Live requests are authorized for Mercado Libre user \(currentUserID)."
            }

            return "Live requests are authorized with a stored Mercado Libre session."
        case let .failed(error):
            return error.localizedDescription
        }
    }

    /// Short label rendered for the `/users/me` validation result.
    var sessionValidationTitle: String {
        switch sessionValidation {
        case .idle:
            return "Session Not Checked"
        case .validating:
            return "Validating Session"
        case .validated:
            return "Session Confirmed"
        case .failed:
            return "Session Validation Failed"
        }
    }

    /// Human-readable explanation of the latest `/users/me` validation result.
    var sessionValidationMessage: String {
        switch sessionValidation {
        case .idle:
            return "Run /users/me to confirm which Mercado Libre account the current bearer token belongs to."
        case .validating:
            return "Checking /users/me with the current bearer token."
        case let .validated(user):
            if let nickname = user.nickname, !nickname.isEmpty {
                if let siteID = user.siteID, !siteID.isEmpty {
                    return "/users/me resolved Mercado Libre user \(user.id) (\(nickname)) for site \(siteID)."
                }

                return "/users/me resolved Mercado Libre user \(user.id) (\(nickname))."
            }

            return "/users/me resolved Mercado Libre user \(user.id)."
        case let .failed(error):
            return error.localizedDescription
        }
    }

    /// Prepares the session by resolving demo mode, environment credentials, or a persisted OAuth session.
    func prepareIfNeeded() async {
        guard !hasPrepared else {
            return
        }

        hasPrepared = true
        latestError = nil

        guard !configuration.isUsingDemoData else {
            status = .demoMode
            return
        }

        guard configuration.accessToken == nil else {
            status = .usingEnvironmentAccessToken
            return
        }

        guard canAuthorizeInteractively else {
            status = .missingConfiguration
            return
        }

        do {
            guard let persistedCredentials = try loadPersistedCredentials() else {
                status = .signedOut
                return
            }

            self.persistedCredentials = persistedCredentials
            currentUserID = persistedCredentials.userID

            if persistedCredentials.requiresRefresh {
                _ = try await refreshStoredCredentials()
            } else {
                status = .authenticated
            }
        } catch {
            let appError = AppError.from(error)
            latestError = appError
            status = .failed(appError)
        }
    }

    /// Builds the Mercado Libre authorization URL for the current OAuth attempt.
    /// - Returns: A browser-ready authorization URL.
    /// - Throws: `AppError.missingOAuthConfiguration` when the local OAuth settings are incomplete.
    func authorizationURL() throws -> URL {
        guard let oauthConfiguration else {
            status = .missingConfiguration
            throw AppError.missingOAuthConfiguration
        }

        let pendingAuthorization = PendingAuthorization()
        self.pendingAuthorization = pendingAuthorization
        sessionValidation = .idle
        latestError = nil
        status = .authorizing

        var components = URLComponents(url: oauthConfiguration.authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: oauthConfiguration.clientID),
            URLQueryItem(name: "redirect_uri", value: oauthConfiguration.redirectURL.absoluteString),
            URLQueryItem(name: "state", value: pendingAuthorization.state)
        ]

        guard let url = components?.url else {
            throw AppError.invalidURL
        }

        return url
    }

    /// Completes the OAuth flow from a pasted callback URL returned by the current authorization attempt.
    /// - Parameter callbackInput: Full redirect URL returned by Mercado Libre for the current browser flow.
    /// - Returns: `true` when token exchange succeeded and the session was persisted.
    @discardableResult
    func completeAuthorization(from callbackInput: String) async -> Bool {
        do {
            try await exchangeAuthorizationCode(using: callbackInput)
            return true
        } catch {
            let appError = AppError.from(error)
            latestError = appError
            status = .failed(appError)
            AppLogger.authentication.error("OAuth completion failed: \(appError.developerDescription)")
            return false
        }
    }

    /// Deletes the persisted OAuth session and resets the visible authentication state.
    func signOut() {
        pendingAuthorization = nil
        persistedCredentials = nil
        currentUserID = nil
        latestError = nil
        sessionValidation = .idle

        do {
            try keychainStore.delete()
        } catch {
            AppLogger.authentication.error("OAuth keychain delete failed: \(error.localizedDescription, privacy: .public)")
        }

        if configuration.isUsingDemoData {
            status = .demoMode
        } else if configuration.accessToken != nil {
            status = .usingEnvironmentAccessToken
        } else if canAuthorizeInteractively {
            status = .signedOut
        } else {
            status = .missingConfiguration
        }
    }

    /// Resolves a bearer token that is safe to use for the next live API request.
    /// - Returns: An access token from the environment, the keychain, or a refresh flow.
    /// - Throws: `AppError` when the app cannot provide a usable token.
    func validAccessToken() async throws -> String {
        await prepareIfNeeded()

        if let environmentAccessToken = configuration.accessToken {
            return environmentAccessToken
        }

        guard canAuthorizeInteractively else {
            throw AppError.missingOAuthConfiguration
        }

        if let persistedCredentials, !persistedCredentials.requiresRefresh {
            status = .authenticated
            currentUserID = persistedCredentials.userID
            return persistedCredentials.accessToken
        }

        if persistedCredentials != nil {
            return try await refreshStoredCredentials()
        }

        status = .signedOut
        throw AppError.missingAccessToken
    }

    /// Confirms the current bearer token by calling Mercado Libre's `/users/me` endpoint.
    /// - Returns: `true` when Mercado Libre accepts the current bearer token and returns a user payload.
    @discardableResult
    func validateCurrentSession() async -> Bool {
        guard canValidateCurrentSession else {
            return false
        }

        sessionValidation = .validating
        latestError = nil

        do {
            let accessToken = try await validAccessToken()
            var request = URLRequest(url: URL(string: "https://api.mercadolibre.com/users/me")!)
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            guard 200 ..< 300 ~= httpResponse.statusCode else {
                let mappedError = mapStatusCode(httpResponse.statusCode)
                let responseBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
                AppLogger.authentication.error(
                    "Session validation failed: \(mappedError.developerDescription). Response body: \(responseBody, privacy: .public)"
                )
                throw mappedError
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let user = try decoder.decode(ValidatedUser.self, from: data)

            currentUserID = user.id
            sessionValidation = .validated(user)
            AppLogger.authentication.info(
                "Validated Mercado Libre session for user \(String(user.id), privacy: .public)"
            )
            return true
        } catch {
            let appError = AppError.from(error)
            latestError = appError
            sessionValidation = .failed(appError)
            AppLogger.authentication.error("Session validation failed: \(appError.developerDescription)")
            return false
        }
    }

    /// Exchanges the current authorization code for access and refresh tokens.
    /// - Parameter callbackInput: Full callback URL supplied by the user for the current browser flow.
    private func exchangeAuthorizationCode(using callbackInput: String) async throws {
        guard let oauthConfiguration else {
            throw AppError.missingOAuthConfiguration
        }

        let authorizationCode = try parseAuthorizationCode(from: callbackInput)
        status = .exchangingCode
        latestError = nil

        let response = try await requestToken(
            endpoint: oauthConfiguration.tokenEndpoint,
            formItems: [
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "client_id", value: oauthConfiguration.clientID),
                URLQueryItem(name: "client_secret", value: oauthConfiguration.clientSecret),
                URLQueryItem(name: "code", value: authorizationCode.code),
                URLQueryItem(name: "redirect_uri", value: oauthConfiguration.redirectURL.absoluteString)
            ]
        )

        try persist(response)
        pendingAuthorization = nil
        status = .authenticated
    }

    /// Uses the stored refresh token to renew the persisted Mercado Libre session.
    /// - Returns: The refreshed access token.
    private func refreshStoredCredentials() async throws -> String {
        guard let oauthConfiguration else {
            throw AppError.missingOAuthConfiguration
        }

        guard let refreshToken = persistedCredentials?.refreshToken else {
            throw AppError.missingAccessToken
        }

        status = .refreshing
        latestError = nil

        let response = try await requestToken(
            endpoint: oauthConfiguration.tokenEndpoint,
            formItems: [
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "client_id", value: oauthConfiguration.clientID),
                URLQueryItem(name: "client_secret", value: oauthConfiguration.clientSecret),
                URLQueryItem(name: "refresh_token", value: refreshToken)
            ]
        )

        try persist(response)
        status = .authenticated
        return response.accessToken
    }

    /// Sends a token-related form request to Mercado Libre.
    /// - Parameters:
    ///   - endpoint: Token endpoint URL.
    ///   - formItems: Form-encoded OAuth parameters.
    /// - Returns: The decoded token payload returned by Mercado Libre.
    private func requestToken(
        endpoint: URL,
        formItems: [URLQueryItem]
    ) async throws -> TokenResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formItems
            .compactMap { item -> String? in
                guard let value = item.value else {
                    return nil
                }

                return "\(item.name)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let mappedError = mapStatusCode(httpResponse.statusCode)
            let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            AppLogger.authentication.error(
                "OAuth token request failed: \(mappedError.developerDescription). Response body: \(body, privacy: .public)"
            )
            throw mappedError
        }

        let decoder = JSONDecoder()
        return try decoder.decode(TokenResponse.self, from: data)
    }

    /// Loads any previously persisted OAuth credentials from the keychain.
    private func loadPersistedCredentials() throws -> StoredCredentials? {
        guard let data = try keychainStore.load() else {
            return nil
        }

        return try JSONDecoder().decode(StoredCredentials.self, from: data)
    }

    /// Persists a successful OAuth response and updates the in-memory session state.
    /// - Parameter tokenResponse: Mercado Libre token payload returned by authorization or refresh.
    private func persist(_ tokenResponse: TokenResponse) throws {
        let storedCredentials = StoredCredentials(tokenResponse: tokenResponse)
        let data = try JSONEncoder().encode(storedCredentials)

        try keychainStore.save(data)
        persistedCredentials = storedCredentials
        currentUserID = storedCredentials.userID
        sessionValidation = .idle
        let scopeDescription = storedCredentials.scope ?? "<none>"
        let userDescription = storedCredentials.userID.map(String.init) ?? "<unknown>"
        AppLogger.authentication.info(
            "Stored Mercado Libre OAuth session for user \(userDescription, privacy: .public) with scope \(scopeDescription, privacy: .public)"
        )
    }

    /// Parses the authorization callback URL and validates that it matches the current pending authorization.
    /// - Parameter input: Full callback URL returned by the registered Mercado Libre redirect.
    /// - Returns: A normalized authorization code wrapper.
    private func parseAuthorizationCode(from input: String) throws -> AuthorizationCode {
        guard let oauthConfiguration else {
            throw AppError.missingOAuthConfiguration
        }

        guard let pendingAuthorization else {
            throw AppError.invalidAuthorizationCallback
        }

        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw AppError.invalidAuthorizationCallback
        }

        guard
            let callbackURL = URL(string: trimmedInput),
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        else {
            throw AppError.invalidAuthorizationCallback
        }

        guard callbackMatchesRegisteredRedirect(callbackURL, expected: oauthConfiguration.redirectURL) else {
            throw AppError.invalidAuthorizationCallback
        }

        guard
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
            !code.isEmpty,
            let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
            returnedState == pendingAuthorization.state
        else {
            throw AppError.invalidAuthorizationCallback
        }

        return AuthorizationCode(code: code)
    }

    /// Ensures the callback URL belongs to the registered redirect endpoint before reading the code or state.
    private func callbackMatchesRegisteredRedirect(_ callbackURL: URL, expected redirectURL: URL) -> Bool {
        guard
            let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let redirectComponents = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false)
        else {
            return false
        }

        return callbackComponents.scheme?.lowercased() == redirectComponents.scheme?.lowercased()
            && callbackComponents.host?.lowercased() == redirectComponents.host?.lowercased()
            && callbackComponents.port == redirectComponents.port
            && callbackComponents.path == redirectComponents.path
    }
}

private extension MELIAuthenticationSession {
    /// Wrapper used to make it explicit when the app already normalized the pasted code value.
    struct AuthorizationCode {
        let code: String
    }

    /// State material that stays in memory only for the current authorization attempt.
    struct PendingAuthorization {
        let state: String

        init() {
            state = Self.randomURLSafeString(byteCount: 24)
        }

        private static func randomURLSafeString(byteCount: Int) -> String {
            let bytes = (0 ..< byteCount).map { _ in UInt8.random(in: .min ... .max) }
            return Data(bytes)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
    }

    /// Persisted OAuth credentials stored in the keychain for future launches.
    struct StoredCredentials: Codable, Equatable, Sendable {
        let accessToken: String
        let refreshToken: String?
        let expirationDate: Date
        let scope: String?
        let userID: Int?

        /// Creates a storable representation from Mercado Libre's token response.
        /// - Parameters:
        ///   - tokenResponse: OAuth payload returned by Mercado Libre.
        ///   - now: Reference date used to compute the expiration timestamp.
        init(tokenResponse: TokenResponse, now: Date = .init()) {
            accessToken = tokenResponse.accessToken
            refreshToken = tokenResponse.refreshToken
            expirationDate = now.addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            scope = tokenResponse.scope
            userID = tokenResponse.userID
        }

        /// Indicates whether the access token should be refreshed before the next live request.
        var requiresRefresh: Bool {
            expirationDate <= Date().addingTimeInterval(300)
        }
    }

    /// Decodable representation of Mercado Libre's token endpoint response.
    struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int
        let scope: String?
        let userID: Int?

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case scope
            case userID = "user_id"
        }
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var characterSet = CharacterSet.urlQueryAllowed
        characterSet.remove(charactersIn: "&+=?")
        return characterSet
    }()
}

private extension MELIAuthenticationSession {
    /// Converts HTTP status codes into domain-specific errors for the auth and validation flows.
    func mapStatusCode(_ statusCode: Int) -> AppError {
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
