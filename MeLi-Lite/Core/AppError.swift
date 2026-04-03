import Foundation

enum AppError: Error, LocalizedError, Equatable, Sendable {
    case missingAccessToken
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case httpStatus(Int)
    case decoding(String)
    case transport(URLError.Code)
    case unknown(String)

    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let decodingError = error as? DecodingError {
            return .decoding(decodingError.localizedDescription)
        }

        if let urlError = error as? URLError {
            return .transport(urlError.code)
        }

        return .unknown(error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Live Mercado Libre requests need an access token."
        case .invalidURL, .invalidResponse:
            return "The app could not understand the server response."
        case .unauthorized:
            return "The configured Mercado Libre token is not valid anymore."
        case .forbidden:
            return "Mercado Libre rejected this request."
        case let .httpStatus(statusCode):
            return "The server answered with status code \(statusCode)."
        case .decoding:
            return "The app received data in an unexpected format."
        case let .transport(code):
            switch code {
            case .notConnectedToInternet:
                return "You're offline right now."
            case .timedOut:
                return "The request took too long to finish."
            default:
                return "The network request could not be completed."
            }
        case .unknown:
            return "Something unexpected happened."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingAccessToken:
            return "Add MELI_ACCESS_TOKEN to your scheme environment variables or use demo mode."
        case .unauthorized, .forbidden:
            return "Refresh your credentials or switch the app back to demo mode."
        case .transport(.notConnectedToInternet):
            return "Check your network connection and try again."
        default:
            return "Try the request again in a moment."
        }
    }

    var developerDescription: String {
        switch self {
        case .missingAccessToken:
            return "Missing MELI_ACCESS_TOKEN while using the live data source."
        case .invalidURL:
            return "Failed to construct a valid Mercado Libre URL request."
        case .invalidResponse:
            return "Received a non-HTTP or malformed response object."
        case .unauthorized:
            return "Mercado Libre returned HTTP 401."
        case .forbidden:
            return "Mercado Libre returned HTTP 403."
        case let .httpStatus(statusCode):
            return "Mercado Libre returned unexpected HTTP status \(statusCode)."
        case let .decoding(message):
            return "Failed to decode Mercado Libre payload: \(message)"
        case let .transport(code):
            return "URLSession transport error: \(code.rawValue)"
        case let .unknown(message):
            return "Unexpected error: \(message)"
        }
    }
}
