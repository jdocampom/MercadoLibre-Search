import Foundation

struct AppContainer {
    let configuration: AppConfiguration
    let productRepository: ProductRepository

    static func bootstrap(configuration: AppConfiguration = .current) -> AppContainer {
        let repository = configuration.isUsingDemoData
            ? DemoProductRepository.makeRepository()
            : LiveProductRepository.makeRepository(configuration: configuration)

        return AppContainer(configuration: configuration, productRepository: repository)
    }
}
