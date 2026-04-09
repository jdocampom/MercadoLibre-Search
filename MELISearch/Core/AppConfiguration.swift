import Foundation
import OSLog

/// Runtime configuration assembled from process environment variables.
struct AppConfiguration: Equatable, Sendable {
    /// Persisted OAuth values reused when the app relaunches without Xcode environment variables.
    struct PersistedOAuthConfiguration: Codable, Equatable, Sendable {
        /// Mercado Libre site identifier used to derive the correct auth host.
        let siteID: String
        /// OAuth app identifier registered in Mercado Libre.
        let oauthClientID: String
        /// OAuth client secret required by the current token exchange implementation.
        let oauthClientSecret: String
        /// Redirect URL registered for the OAuth app.
        let oauthRedirectURL: URL
        /// Authorization host used to open the grant page.
        let oauthAuthorizationHost: String
    }

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

    /// Default configuration loaded from scheme/process environment variables and a persisted local OAuth fallback.
    static let current = resolveCurrent()

    /// Resolves the active configuration from a raw environment dictionary.
    /// - Parameter environment: Process environment values used to configure the app session.
    /// - Returns: A normalized configuration used by the composition root and shared services.
    static func resolve(environment: [String: String]) -> AppConfiguration {
        resolve(environment: environment, persistedOAuthConfiguration: nil)
    }

    /// Resolves the active configuration from the raw environment plus a persisted OAuth fallback.
    /// - Parameters:
    ///   - environment: Process environment values used to configure the app session.
    ///   - persistedOAuthConfiguration: Stored local OAuth configuration reused when the process environment is empty.
    /// - Returns: A normalized configuration used by the composition root and shared services.
    static func resolve(
        environment: [String: String],
        persistedOAuthConfiguration: PersistedOAuthConfiguration?
    ) -> AppConfiguration {
        let accessToken = environment["MELI_ACCESS_TOKEN"]?.trimmedNonEmptyValue
        let environmentSiteID = environment["MELI_SITE_ID"]?.trimmedNonEmptyValue
        let siteID = environmentSiteID ?? persistedOAuthConfiguration?.siteID ?? "MCO"
        let requestedSource = environment["MELI_DATA_SOURCE"]
            .map { $0.lowercased() }
            .flatMap(DataSource.init(rawValue:))
        let oauthAuthorizationHost = resolveOAuthAuthorizationHost(
            environment: environment,
            siteID: siteID,
            persistedOAuthConfiguration: persistedOAuthConfiguration
        )
        let oauthClientID = environment["MELI_APP_ID"]?.trimmedNonEmptyValue
            ?? persistedOAuthConfiguration?.oauthClientID
        let oauthClientSecret = environment["MELI_CLIENT_SECRET"]?.trimmedNonEmptyValue
            ?? persistedOAuthConfiguration?.oauthClientSecret
        let oauthRedirectURL = environment["MELI_REDIRECT_URL"]?.trimmedNonEmptyValue
            .flatMap(URL.init(string:))
            ?? persistedOAuthConfiguration?.oauthRedirectURL
        let hasInteractiveOAuth =
            oauthClientID != nil
                && oauthClientSecret != nil
                && oauthRedirectURL != nil
                && oauthAuthorizationHost != nil
        let dataSource: DataSource

        switch requestedSource {
        case .demo?:
            dataSource = .demo
        case .live?:
            dataSource = .live
        case nil:
            dataSource = accessToken != nil || hasInteractiveOAuth ? .live : .demo
        }

        return AppConfiguration(
            dataSource: dataSource,
            siteID: siteID,
            accessToken: accessToken,
            oauthClientID: oauthClientID,
            oauthClientSecret: oauthClientSecret,
            oauthRedirectURL: oauthRedirectURL,
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

private extension AppConfiguration {
    /// Loads the process configuration while reusing the last complete local OAuth setup when possible.
    static func resolveCurrent(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppConfiguration {
        let store = PersistedOAuthConfigurationStore()
        let persistedOAuthConfiguration = store.synchronizeAndLoad(environment: environment)
        return resolve(
            environment: environment,
            persistedOAuthConfiguration: persistedOAuthConfiguration
        )
    }

    /// Resolves the preferred OAuth host without mixing a new site identifier with an old persisted host.
    static func resolveOAuthAuthorizationHost(
        environment: [String: String],
        siteID: String,
        persistedOAuthConfiguration: PersistedOAuthConfiguration?
    ) -> String? {
        if let explicitEnvironmentHost = environment["MELI_AUTH_HOST"]?.trimmedNonEmptyValue {
            return explicitEnvironmentHost
        }

        if environment["MELI_SITE_ID"]?.trimmedNonEmptyValue != nil {
            return MELIOAuthConfiguration.defaultAuthorizationHost(forSiteID: siteID)
        }

        return persistedOAuthConfiguration?.oauthAuthorizationHost
            ?? MELIOAuthConfiguration.defaultAuthorizationHost(forSiteID: siteID)
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

/// Persists a complete OAuth setup so the app can relaunch outside Xcode and still reauthorize later.
private struct PersistedOAuthConfigurationStore {
    /// Dedicated keychain location for the local developer OAuth configuration.
    private let keychainStore = KeychainStore(
        service: "com.jdocampo.MeLi-Lite.mercadolibre.oauth-configuration",
        account: "default"
    )

    /// Merges environment values over the last stored configuration and saves the result when it changed.
    /// - Parameter environment: Process environment values used for the current launch.
    /// - Returns: The best complete persisted OAuth configuration available for this launch.
    func synchronizeAndLoad(environment: [String: String]) -> AppConfiguration.PersistedOAuthConfiguration? {
        do {
            let existingConfiguration = try load()
            let mergedConfiguration = mergedConfiguration(
                environment: environment,
                existingConfiguration: existingConfiguration
            )

            if let mergedConfiguration, mergedConfiguration != existingConfiguration {
                try save(mergedConfiguration)
            }

            return mergedConfiguration
        } catch {
            AppLogger.authentication.error(
                "Persisted OAuth configuration sync failed: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    /// Loads the last saved OAuth configuration when present.
    func load() throws -> AppConfiguration.PersistedOAuthConfiguration? {
        guard let data = try keychainStore.load() else {
            return nil
        }

        return try JSONDecoder().decode(AppConfiguration.PersistedOAuthConfiguration.self, from: data)
    }

    /// Saves a new OAuth configuration snapshot to Keychain.
    func save(_ configuration: AppConfiguration.PersistedOAuthConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        try keychainStore.save(data)
    }

    /// Combines environment overrides with the last saved configuration and returns a complete result only when possible.
    func mergedConfiguration(
        environment: [String: String],
        existingConfiguration: AppConfiguration.PersistedOAuthConfiguration?
    ) -> AppConfiguration.PersistedOAuthConfiguration? {
        let environmentSiteID = environment["MELI_SITE_ID"]?.trimmedNonEmptyValue
        let siteID = environmentSiteID ?? existingConfiguration?.siteID
        let oauthClientID = environment["MELI_APP_ID"]?.trimmedNonEmptyValue
            ?? existingConfiguration?.oauthClientID
        let oauthClientSecret = environment["MELI_CLIENT_SECRET"]?.trimmedNonEmptyValue
            ?? existingConfiguration?.oauthClientSecret
        let oauthRedirectURL = environment["MELI_REDIRECT_URL"]?.trimmedNonEmptyValue
            .flatMap(URL.init(string:))
            ?? existingConfiguration?.oauthRedirectURL
        let oauthAuthorizationHost =
            if let explicitEnvironmentHost = environment["MELI_AUTH_HOST"]?.trimmedNonEmptyValue {
                explicitEnvironmentHost
            } else if let environmentSiteID {
                MELIOAuthConfiguration.defaultAuthorizationHost(forSiteID: environmentSiteID)
            } else {
                existingConfiguration?.oauthAuthorizationHost
                    ?? siteID.flatMap(MELIOAuthConfiguration.defaultAuthorizationHost(forSiteID:))
            }

        guard
            let siteID,
            let oauthClientID,
            let oauthClientSecret,
            let oauthRedirectURL,
            let oauthAuthorizationHost
        else {
            return existingConfiguration
        }

        return AppConfiguration.PersistedOAuthConfiguration(
            siteID: siteID,
            oauthClientID: oauthClientID,
            oauthClientSecret: oauthClientSecret,
            oauthRedirectURL: oauthRedirectURL,
            oauthAuthorizationHost: oauthAuthorizationHost
        )
    }
}
