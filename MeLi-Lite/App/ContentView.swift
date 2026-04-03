import SwiftUI

struct ContentView: View {
    private let container: AppContainer

    @State private var viewModel: SearchViewModel
    @State private var connectivityMonitor: ConnectivityMonitor

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(
            initialValue: SearchViewModel(
                repository: container.productRepository,
                configuration: container.configuration
            )
        )
        _connectivityMonitor = State(initialValue: container.connectivityMonitor)
    }

    var body: some View {
        NavigationStack {
            SearchScreen(
                viewModel: viewModel,
                connectivityMonitor: connectivityMonitor
            )
                .navigationDestination(for: ProductSummary.self) { product in
                    ProductDetailScreen(
                        product: product,
                        repository: container.productRepository,
                        configuration: container.configuration
                    )
                }
        }
    }
}

#Preview {
    ContentView(container: .bootstrap(configuration: .preview))
}
