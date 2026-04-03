import SwiftUI

/// The root navigation host that injects shared dependencies into the search and detail flows.
struct ContentView: View {
    /// The shared container passed down from the app entry point.
    private let container: AppContainer

    /// The shared OAuth session that manages live Mercado Libre authorization.
    @State private var authenticationSession: MercadoLibreAuthenticationSession
    /// The search view model so it survives SwiftUI view refreshes.
    @State private var viewModel: SearchViewModel
    
    /// The  connectivity monitor shared with the search screen.
    @State private var connectivityMonitor: ConnectivityMonitor

    /// Builds the root screen graph with dependencies sourced from the app container.
    ///
    /// - Parameters:
    ///   - container: Shared dependencies assembled by the app entry point.
    ///   
    init(container: AppContainer) {
        self.container = container
        _authenticationSession = State(initialValue: container.authenticationSession)
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
                connectivityMonitor: connectivityMonitor,
                authenticationSession: authenticationSession
            )
            .navigationDestination(for: ProductSummary.self) { product in
                ProductDetailScreen(
                    product: product,
                    repository: container.productRepository,
                    configuration: container.configuration
                )
            }
        }
        .task {
            await authenticationSession.prepareIfNeeded()
        }
        .onOpenURL { url in
            Task {
                _ = await authenticationSession.completeAuthorization(from: url.absoluteString)
            }
        }
    }
}

#Preview {
    ContentView(container: .main(configuration: .preview))
}
