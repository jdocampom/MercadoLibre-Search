//
//  MeLiLiteApp.swift
//  MeLi-Lite
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import SwiftUI

/// The application entry point that builds the dependency container once and injects it into the root UI.
@main
struct MeLiLiteApp: App {
    /// The shared dependency graph used by the initial scene.
    private let container = AppContainer.main()

    /// Creates the main app scene and injects the shared container into the root content view.
    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                // The current challenge UI is intentionally light-themed.
                // Keep semantic text and materials readable across iOS and macOS.
                .preferredColorScheme(.light)
        }
    }
}
