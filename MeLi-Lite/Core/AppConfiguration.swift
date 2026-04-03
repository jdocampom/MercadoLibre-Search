import Foundation

struct AppConfiguration: Equatable, Sendable {
    enum DataSource: String, Sendable {
        case demo
        case live
    }

    let dataSource: DataSource
    let siteID: String
    let accessToken: String?

    static let current: AppConfiguration = {
        let environment = ProcessInfo.processInfo.environment
        let accessToken = environment["MELI_ACCESS_TOKEN"]?.trimmedNonEmptyValue
        let requestedSource = environment["MELI_DATA_SOURCE"]?.lowercased()
        let dataSource: DataSource

        if requestedSource == DataSource.live.rawValue || accessToken != nil {
            dataSource = .live
        } else {
            dataSource = .demo
        }

        return AppConfiguration(
            dataSource: dataSource,
            siteID: environment["MELI_SITE_ID"]?.trimmedNonEmptyValue ?? "MCO",
            accessToken: accessToken
        )
    }()

    static let preview = AppConfiguration(dataSource: .demo, siteID: "MCO", accessToken: nil)

    var isUsingDemoData: Bool {
        dataSource == .demo
    }

    var environmentBadge: String {
        isUsingDemoData ? "Demo Catalog" : "Live API"
    }

    var assistantNote: String {
        if isUsingDemoData {
            return "Demo data is enabled by default because Mercado Libre product search currently requires authorization. Configure MELI_DATA_SOURCE=live and MELI_ACCESS_TOKEN to use live requests."
        }

        return "Live Mercado Libre requests are enabled for site \(siteID)."
    }
}

private extension String {
    var trimmedNonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
