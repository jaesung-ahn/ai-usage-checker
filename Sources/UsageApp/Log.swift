import OSLog

/// 앱 로그. 토큰과 응답 본문은 절대 남기지 않는다.
enum Log {
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let ui = Logger(subsystem: subsystem, category: "ui")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "ai-usage-checker"
}
