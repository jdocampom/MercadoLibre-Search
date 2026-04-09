import Foundation

/// A lightweight dependency container used to wire repositories and shared services into the UI layer.
struct AppContainer {
    /// The environment-driven runtime settings.
    let configuration: AppConfiguration
    /// The shared OAuth session used by live Mercado Libre flows.
    let authenticationSession: MELIAuthenticationSession
    /// The product data source resolved from the active configuration.
    let productRepository: ProductRepository
    /// The shared reachability monitor observed by search-related screens.
    let connectivityMonitor: ConnectivityMonitor
    /// The persisted favorites selected by the user.
    let favoritesStore: FavoritesStore

    /// Creates the dependency container for the current runtime environment.
    /// - Parameters:
    ///   - configuration: Runtime settings used to resolve the active data source.
    ///   - favoritesStore: Persisted favorites store reused across container rebuilds.
    /// - Returns: A fully wired dependency container for the app.
    static func main(
        configuration: AppConfiguration = .current,
        favoritesStore: FavoritesStore = FavoritesStore()
    ) -> AppContainer {
        let authenticationSession = MELIAuthenticationSession(configuration: configuration)
        let repository = configuration.isUsingDemoData
            ? DemoProductRepository.makeRepository()
            : LiveProductRepository.makeRepository(
                configuration: configuration,
                accessTokenProvider: authenticationSession.validAccessToken,
                searchSiteIDProvider: authenticationSession.resolvedSearchSiteID
            )

        return AppContainer(
            configuration: configuration,
            authenticationSession: authenticationSession,
            productRepository: repository,
            connectivityMonitor: ConnectivityMonitor(),
            favoritesStore: favoritesStore
        )
    }
}
