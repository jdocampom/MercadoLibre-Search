//
//  MeLiLiteApp.swift
//  MeLi-Lite
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import SwiftUI

@main
struct MeLiLiteApp: App {
    private let container = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                // The current challenge UI is intentionally light-themed.
                // Keep semantic text and materials readable across iOS and macOS.
                .preferredColorScheme(.light)
        }
    }
}
