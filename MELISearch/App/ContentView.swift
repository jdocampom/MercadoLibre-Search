import SwiftUI

/// The root navigation host that injects shared dependencies into the search and detail flows.
struct ContentView: View {
    /// The startup configuration used as the basis for runtime demo/live overrides.
    private let baseConfiguration: AppConfiguration

    /// The active dependency container for the currently selected data source.
    @State private var activeContainer: AppContainer
    /// The shared OAuth session that manages live Mercado Libre authorization.
    @State private var authenticationSession: MELIAuthenticationSession
    /// The search view model so it survives SwiftUI view refreshes.
    @State private var viewModel: SearchViewModel
    /// The  connectivity monitor shared with the search screen.
    @State private var connectivityMonitor: ConnectivityMonitor
    /// Resets the navigation tree when switching between demo and live.
    @State private var navigationIdentity = UUID()

    /// Builds the root screen graph with dependencies sourced from the app container.
    /// - Parameters:
    ///   - container: Shared dependencies assembled by the app entry point.
    init(container: AppContainer) {
        baseConfiguration = container.configuration
        _activeContainer = State(initialValue: container)
        _authenticationSession = State(initialValue: container.authenticationSession)
        _viewModel = State(
            initialValue: SearchViewModel(
                repository: container.productRepository,
                configuration: container.configuration
            )
        )
        _connectivityMonitor = State(initialValue: container.connectivityMonitor)
    }

    /// Renders the root navigation stack and coordinates OAuth callback completion from incoming URLs.
    var body: some View {
        NavigationStack {
            SearchScreen(
                viewModel: viewModel,
                connectivityMonitor: connectivityMonitor,
                authenticationSession: authenticationSession,
                onSelectDataSource: switchDataSource(to:)
            )
            .navigationDestination(for: ProductSummary.self) { product in
                ProductDetailScreen(
                    product: product,
                    repository: activeContainer.productRepository,
                    configuration: activeContainer.configuration
                )
            }
        }
        .id(navigationIdentity)
        .task {
            await authenticationSession.prepareIfNeeded()
        }
        .onOpenURL { url in
            Task {
                _ = await authenticationSession.completeAuthorizationIfPossible(from: url)
            }
        }
    }
}

private extension ContentView {
    /// Rebuilds the app container for the selected data source and resets UI state that depends on it.
    /// - Parameter dataSource: Runtime backend mode that should become active.
    func switchDataSource(to dataSource: AppConfiguration.DataSource) {
        guard activeContainer.configuration.dataSource != dataSource else {
            return
        }

        let updatedConfiguration = baseConfiguration.overriding(dataSource: dataSource)
        let updatedContainer = AppContainer.main(configuration: updatedConfiguration)

        activeContainer = updatedContainer
        authenticationSession = updatedContainer.authenticationSession
        viewModel = SearchViewModel(
            repository: updatedContainer.productRepository,
            configuration: updatedContainer.configuration
        )
        connectivityMonitor = updatedContainer.connectivityMonitor
        navigationIdentity = UUID()
    }
}

#Preview {
    ContentView(container: .main(configuration: .preview))
}
