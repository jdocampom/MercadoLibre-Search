import SwiftUI

/// Root navigation host that injects shared dependencies into the search and detail flows.
struct ContentView: View {
    /// Shared container passed down from the app entry point.
    private let container: AppContainer

    /// State-backed search view model so it survives SwiftUI view refreshes.
    @State private var viewModel: SearchViewModel
    /// State-backed connectivity monitor shared with the search screen.
    @State private var connectivityMonitor: ConnectivityMonitor

    /// Builds the root screen graph with dependencies sourced from the app container.
    /// - Parameter container: Shared dependencies assembled by the app entry point.
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
