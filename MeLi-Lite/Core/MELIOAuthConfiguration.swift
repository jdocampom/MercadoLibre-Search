import Foundation

/// OAuth client settings required to authorize the app against Mercado Libre.
struct MELIOAuthConfiguration: Equatable, Sendable {
    /// Mercado Libre application identifier.
    let clientID: String
    /// Mercado Libre application secret used during token exchange and refresh.
    let clientSecret: String
    /// Registered redirect URL that must exactly match the app configuration in Mercado Libre.
    let redirectURL: URL
    /// Country-specific host used for the authorization page.
    let authorizationHost: String

    /// Full browser endpoint used to request user authorization.
    var authorizationEndpoint: URL {
        URL(string: "https://\(authorizationHost)/authorization")!
    }

    /// Shared token endpoint used to exchange codes and refresh tokens.
    var tokenEndpoint: URL {
        URL(string: "https://api.mercadolibre.com/oauth/token")!
    }

    /// Resolves the recommended Mercado Libre authorization host for a site identifier.
    /// - Parameter siteID: Mercado Libre site code such as `MCO` or `MLA`.
    /// - Returns: The matching host when the site is known, otherwise `nil`.
    static func defaultAuthorizationHost(forSiteID siteID: String) -> String? {
        switch siteID.uppercased() {
        case "MCO":
            return "auth.mercadolibre.com.co"
        case "MLA":
            return "auth.mercadolibre.com.ar"
        case "MLM":
            return "auth.mercadolibre.com.mx"
        case "MLB":
            return "auth.mercadolivre.com.br"
        case "MLC":
            return "auth.mercadolibre.cl"
        case "MPE":
            return "auth.mercadolibre.com.pe"
        case "MLU":
            return "auth.mercadolibre.com.uy"
        case "MEC":
            return "auth.mercadolibre.com.ec"
        case "MCR":
            return "auth.mercadolibre.co.cr"
        case "MPA":
            return "auth.mercadolibre.com.pa"
        case "MRD":
            return "auth.mercadolibre.com.do"
        case "MGT":
            return "auth.mercadolibre.com.gt"
        case "MHN":
            return "auth.mercadolibre.hn"
        case "MNI":
            return "auth.mercadolibre.com.ni"
        case "MSV":
            return "auth.mercadolibre.com.sv"
        default:
            return nil
        }
    }
}
