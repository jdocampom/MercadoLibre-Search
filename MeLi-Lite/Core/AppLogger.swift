import OSLog

/// Defines a set of centralized logger categories used across the application.
enum AppLogger {
    /// The shared subsystem identifier so logs stay grouped in Console.app.
    private static let subsystem = "com.jdocampo.MeLi-Lite"

    /// The logger for OAuth authorization and session refresh diagnostics.
    static let authentication = Logger(subsystem: subsystem, category: "authentication")
    /// The logger for network request and response diagnostics.
    static let networking = Logger(subsystem: subsystem, category: "networking")
    /// The logger for UI flow and view model diagnostics.
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
