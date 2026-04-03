import Foundation

/// Runtime configuration assembled from process environment variables.
struct AppConfiguration: Equatable, Sendable {
    /// Selects whether the app talks to the live API or uses local fixtures.
    enum DataSource: String, Sendable {
        case demo
        case live
    }

    /// Active backend mode for the current process.
    let dataSource: DataSource
    /// Mercado Libre site identifier used to scope searches.
    let siteID: String
    /// OAuth token required for authenticated live requests.
    let accessToken: String?

    /// Default configuration loaded from scheme or process environment variables.
    static let current = resolve(environment: ProcessInfo.processInfo.environment)

    /// Resolves the active configuration from a raw environment dictionary.
    static func resolve(environment: [String: String]) -> AppConfiguration {
        let accessToken = environment["MELI_ACCESS_TOKEN"]?.trimmedNonEmptyValue
        let requestedSource = environment["MELI_DATA_SOURCE"]
            .map { $0.lowercased() }
            .flatMap(DataSource.init(rawValue:))
        let dataSource: DataSource

        switch requestedSource {
        case .demo?:
            dataSource = .demo
        case .live?:
            dataSource = .live
        case nil:
            dataSource = accessToken == nil ? .demo : .live
        }

        return AppConfiguration(
            dataSource: dataSource,
            siteID: environment["MELI_SITE_ID"]?.trimmedNonEmptyValue ?? "MCO",
            accessToken: accessToken
        )
    }

    /// Stable configuration used by previews and local UI rendering.
    static let preview = AppConfiguration(dataSource: .demo, siteID: "MCO", accessToken: nil)

    /// Indicates whether the app should avoid live network calls.
    var isUsingDemoData: Bool {
        dataSource == .demo
    }

    /// Short label surfaced in the UI to explain the active environment.
    var environmentBadge: String {
        isUsingDemoData ? "Demo Catalog" : "Live API"
    }

    /// Developer-facing explanation of how the current environment was resolved.
    var assistantNote: String {
        if isUsingDemoData {
            return "Demo data is enabled by default because Mercado Libre product search currently requires authorization. Configure MELI_DATA_SOURCE=live and MELI_ACCESS_TOKEN to use live requests."
        }

        return "Live Mercado Libre requests are enabled for site \(siteID)."
    }
}

private extension String {
    /// Returns a trimmed string only when it still contains visible characters.
    /// - Returns: A non-empty trimmed string, or `nil` when the receiver is blank.
    var trimmedNonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
