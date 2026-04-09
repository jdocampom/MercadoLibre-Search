import SwiftUI

/// Saved products experience that lets the user revisit favorites without searching again.
struct FavoritesScreen: View {
    /// Persisted favorites selected from product detail.
    let favoritesStore: FavoritesStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(20)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Favorites")
        #if !os(macOS)
        .modifier(AppNavigationBarStyle())
        #endif
    }
}

private extension FavoritesScreen {
    @ViewBuilder
    /// Resolves the current favorites content state.
    var content: some View {
        if favoritesStore.favorites.isEmpty {
            emptyState
        } else {
            favoritesState
        }
    }

    /// Empty state shown before the user saves any favorites.
    var emptyState: some View {
        ContentUnavailableView {
            Label("No favorites yet", systemImage: "heart")
        } description: {
            Text("Open any product detail and save it to favorites to keep it handy here.")
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
        .accessibilityIdentifier("favoritesEmptyState")
    }

    /// Favorites list shown once at least one product has been saved.
    var favoritesState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(favoritesStore.favorites.count) Saved")
                .font(.headline)
                .accessibilityIdentifier("favoritesCountLabel")

            LazyVStack(spacing: 16) {
                ForEach(favoritesStore.favorites) { product in
                    NavigationLink(value: product) {
                        ProductRowView(product: product)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove from Favorites", role: .destructive) {
                            favoritesStore.remove(product)
                        }
                    }
                    .accessibilityIdentifier("favoriteRow_\(product.id)")
                }
            }
        }
        .accessibilityIdentifier("favoritesState")
    }

    /// Background gradient shared by the saved-products experience.
    var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 1.00, green: 0.97, blue: 0.94), location: 0.00),
                .init(color: Color(red: 0.98, green: 0.93, blue: 0.90), location: 0.30),
                .init(color: Color(red: 0.96, green: 0.89, blue: 0.87), location: 0.65),
                .init(color: Color(red: 0.93, green: 0.84, blue: 0.83), location: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Card fill used across the favorites states.
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.84))
    }
}
