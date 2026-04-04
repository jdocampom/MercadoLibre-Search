import Foundation

/// Runtime configuration assembled from process environment variables.
struct AppConfiguration: Equatable, Sendable {
    /// Selects whether the app talks to the live API or uses local fixtures.
    enum DataSource: String, Sendable {
        /// Uses local in-memory fixtures and avoids live network requests.
        case demo
        /// Uses Mercado Libre's live API and OAuth-capable services.
        case live
    }

    /// Test-only authentication overrides used to make UI states deterministic in UI tests.
    enum UITestAuthenticationState: String, Sendable {
        /// Forces the auth session into an authenticated state without requiring real Keychain data.
        case authenticated
    }

    /// Active backend mode for the current process.
    let dataSource: DataSource
    /// Mercado Libre site identifier used to scope searches.
    let siteID: String
    /// OAuth token required for authenticated live requests.
    let accessToken: String?
    /// Mercado Libre OAuth app identifier used for interactive authorization.
    let oauthClientID: String?
    /// Mercado Libre OAuth client secret used for token exchange in local development.
    let oauthClientSecret: String?
    /// Redirect URL registered for the OAuth app.
    let oauthRedirectURL: URL?
    /// Authorization host used to open the Mercado Libre grant page.
    let oauthAuthorizationHost: String?
    /// Optional UI-test-only authentication override.
    let uiTestAuthenticationState: UITestAuthenticationState?

    /// Default configuration loaded from scheme or process environment variables.
    static let current = resolve(environment: ProcessInfo.processInfo.environment)

    /// Resolves the active configuration from a raw environment dictionary.
    /// - Parameter environment: Process environment values used to configure the app session.
    /// - Returns: A normalized configuration used by the composition root and shared services.
    static func resolve(environment: [String: String]) -> AppConfiguration {
        let accessToken = environment["MELI_ACCESS_TOKEN"]?.trimmedNonEmptyValue
        let siteID = environment["MELI_SITE_ID"]?.trimmedNonEmptyValue ?? "MCO"
        let requestedSource = environment["MELI_DATA_SOURCE"]
            .map { $0.lowercased() }
            .flatMap(DataSource.init(rawValue:))
        let oauthAuthorizationHost = environment["MELI_AUTH_HOST"]?.trimmedNonEmptyValue
            ?? MELIOAuthConfiguration.defaultAuthorizationHost(forSiteID: siteID)
        let dataSource: DataSource

        switch requestedSource {
        case .demo?:
            dataSource = .demo
        case .live?:
            dataSource = .live
        case nil:
            dataSource = accessToken == nil ? .demo : .live
        }

        return AppConfiguration(
            dataSource: dataSource,
            siteID: siteID,
            accessToken: accessToken,
            oauthClientID: environment["MELI_APP_ID"]?.trimmedNonEmptyValue,
            oauthClientSecret: environment["MELI_CLIENT_SECRET"]?.trimmedNonEmptyValue,
            oauthRedirectURL: environment["MELI_REDIRECT_URL"]?.trimmedNonEmptyValue.flatMap(URL.init(string:)),
            oauthAuthorizationHost: oauthAuthorizationHost,
            uiTestAuthenticationState: environment["MELI_UI_TEST_AUTH_STATE"]
                .flatMap(UITestAuthenticationState.init(rawValue:))
        )
    }

    /// Stable configuration used by previews and local UI rendering.
    static let preview = AppConfiguration(
        dataSource: .demo,
        siteID: "MCO",
        accessToken: nil,
        oauthClientID: nil,
        oauthClientSecret: nil,
        oauthRedirectURL: nil,
        oauthAuthorizationHost: MELIOAuthConfiguration.defaultAuthorizationHost(forSiteID: "MCO"),
        uiTestAuthenticationState: nil
    )

    /// Indicates whether the app should avoid live network calls.
    var isUsingDemoData: Bool {
        dataSource == .demo
    }

    /// Short label surfaced in the UI to explain the active environment.
    var environmentBadge: String {
        isUsingDemoData ? "Demo Catalog" : "Live API"
    }

    /// Fully resolved OAuth settings when the required variables are available.
    var oauthConfiguration: MELIOAuthConfiguration? {
        guard
            let oauthClientID,
            let oauthClientSecret,
            let oauthRedirectURL,
            let oauthAuthorizationHost
        else {
            return nil
        }

        return MELIOAuthConfiguration(
            clientID: oauthClientID,
            clientSecret: oauthClientSecret,
            redirectURL: oauthRedirectURL,
            authorizationHost: oauthAuthorizationHost
        )
    }

    /// Developer-facing explanation of how the current environment was resolved.
    var assistantNote: String {
        if isUsingDemoData {
            return "Demo data is enabled by default because Mercado Libre product search currently requires authorization. Configure MELI_DATA_SOURCE=live plus either MELI_ACCESS_TOKEN or the OAuth variables to use live requests."
        }

        if accessToken != nil {
            return "Live Mercado Libre requests are enabled for site \(siteID) using MELI_ACCESS_TOKEN from the environment."
        }

        if oauthConfiguration != nil {
            return "Live Mercado Libre requests are enabled for site \(siteID) and can authorize interactively with Mercado Libre OAuth."
        }

        return "Live Mercado Libre requests are enabled for site \(siteID), but OAuth is not fully configured yet."
    }

    /// Returns a copy of the current configuration with a different runtime data source.
    /// - Parameter dataSource: Data source that should become active for the new configuration copy.
    /// - Returns: A configuration that preserves all OAuth and site settings while changing the backend mode.
    func overriding(dataSource: DataSource) -> AppConfiguration {
        AppConfiguration(
            dataSource: dataSource,
            siteID: siteID,
            accessToken: accessToken,
            oauthClientID: oauthClientID,
            oauthClientSecret: oauthClientSecret,
            oauthRedirectURL: oauthRedirectURL,
            oauthAuthorizationHost: oauthAuthorizationHost,
            uiTestAuthenticationState: uiTestAuthenticationState
        )
    }
}

private extension String {
    /// Returns a trimmed string only when it still contains visible characters.
    /// - Returns: A non-empty trimmed string, or `nil` when the receiver is blank.
    var trimmedNonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
