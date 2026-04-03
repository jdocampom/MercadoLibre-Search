import OSLog

/// Centralized logger categories used across the application.
enum AppLogger {
    /// Shared subsystem identifier so logs stay grouped in Console.app.
    private static let subsystem = "com.jdocampo.MeLi-Lite"

    /// Network request and response diagnostics.
    static let networking = Logger(subsystem: subsystem, category: "networking")
    /// UI flow and view model diagnostics.
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
