import OSLog

enum AppLogger {
    private static let subsystem = "com.jdocampo.MeLi-Lite"

    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
