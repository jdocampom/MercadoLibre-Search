import Foundation

/// A lightweight dependency container used to wire repositories and shared services into the UI layer.
struct AppContainer {
    /// The environment-driven runtime settings.
    let configuration: AppConfiguration

    /// The shared OAuth session used by live Mercado Libre flows.
    let authenticationSession: MercadoLibreAuthenticationSession
    
    /// The product data source resolved from the active configuration.
    let productRepository: ProductRepository
    
    /// The shared reachability monitor observed by search-related screens.
    let connectivityMonitor: ConnectivityMonitor

    /// Creates the dependency container for the current runtime environment.
    /// - Parameters:
    ///   - configuration: Runtime settings used to resolve the active data source.
    ///
    /// - Returns: A fully wired dependency container for the app.
    ///
    static func main(configuration: AppConfiguration = .current) -> AppContainer {
        let authenticationSession = MercadoLibreAuthenticationSession(configuration: configuration)
        let repository = configuration.isUsingDemoData
            ? DemoProductRepository.makeRepository()
            : LiveProductRepository.makeRepository(
                configuration: configuration,
                accessTokenProvider: authenticationSession.validAccessToken
            )

        return AppContainer(
            configuration: configuration,
            authenticationSession: authenticationSession,
            productRepository: repository,
            connectivityMonitor: ConnectivityMonitor()
        )
    }
}
