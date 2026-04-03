import Foundation

struct AppContainer {
    let configuration: AppConfiguration
    let productRepository: ProductRepository
    let connectivityMonitor: ConnectivityMonitor

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
