import Foundation

/// Lightweight dependency container used to wire repositories and shared services into the UI layer.
struct AppContainer {
    /// Environment-driven runtime settings.
    let configuration: AppConfiguration
    /// Product data source resolved from the active configuration.
    let productRepository: ProductRepository
    /// Shared reachability monitor observed by search-related screens.
    let connectivityMonitor: ConnectivityMonitor

    /// Creates the dependency container for the current runtime environment.
    /// - Parameter configuration: Runtime settings used to resolve the active data source.
    /// - Returns: A fully wired dependency container for the app.
    static func bootstrap(configuration: AppConfiguration = .current) -> AppContainer {
        let repository = configuration.isUsingDemoData
            ? DemoProductRepository.makeRepository()
            : LiveProductRepository.makeRepository(configuration: configuration)

        return AppContainer(
            configuration: configuration,
            productRepository: repository,
            connectivityMonitor: ConnectivityMonitor()
        )
    }
}
