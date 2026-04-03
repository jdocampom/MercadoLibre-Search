import SwiftUI

/// Applies a consistent navigation bar appearance across supported platforms.
struct AppNavigationBarStyle: ViewModifier {
    /// Applies toolbar styling on iOS while preserving default behavior on other platforms.
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .toolbarBackground(Color("Toolbar"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarTitleDisplayMode(.inlineLarge)
        #else
        content
        #endif
    }
}
