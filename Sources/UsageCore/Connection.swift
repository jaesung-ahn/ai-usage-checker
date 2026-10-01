import Foundation

/// 공급자 로그인 정보에 대한 연결 상태.
///
/// Claude는 키체인 접근이 macOS 권한 창을 띄운다. 창은 사용자가 이 상태의 안내 버튼을
/// 눌렀을 때만 뜨게 한다.
/// Codex는 파일만 읽어 권한 창이 없다. 로그인 안 됨, 만료, 연결됨만 쓴다.
public enum Connection: Equatable, Sendable {
    /// 사용자가 아직 연결한 적이 없다.
    case notConnected
    /// Claude Code 자격증명이 없다.
    case notLoggedIn
    /// 키체인 접근을 거부했다. 거부는 기억되지 않으므로 다시 읽으면 창이 또 뜬다.
    case accessDenied
    /// 토큰을 읽었으나 서버가 거부했다.
    case expired
    case connected

    /// 공급자를 켠 직후의 상태.
    ///
    /// Claude는 연결 버튼이 키체인 접근 동의다. 첫 자동 조회가 창 없이 확인해 바로잡는다.
    /// Codex는 토글을 켜는 것이 연결 동의다. 문제는 조회 결과로만 드러난다.
    public static func initial(for provider: Provider) -> Connection {
        switch provider {
        case .claude: return .notConnected
        case .codex: return .connected
        }
    }

    /// 사용자 조치가 필요할 때의 안내. 연결되어 있으면 `nil`이다.
    public func prompt(for provider: Provider) -> ConnectionPrompt? {
        switch provider {
        case .claude: return claudePrompt
        case .codex: return codexPrompt
        }
    }

    private var claudePrompt: ConnectionPrompt? {
        switch self {
        case .connected: return nil
        case .notConnected: return ConnectionPrompt(.claude, "notConnected", actionKey: "action.connect")
        case .notLoggedIn: return ConnectionPrompt(.claude, "notLoggedIn", actionKey: "action.recheck")
        case .accessDenied: return ConnectionPrompt(.claude, "accessDenied", actionKey: "action.retry")
        case .expired: return ConnectionPrompt(.claude, "expired", actionKey: "action.reconnect")
        }
    }

    /// 앱이 토큰을 갱신하지 않으므로 만료도 다시 확인만 할 수 있다. Codex를 실행하면 갱신된다.
    private var codexPrompt: ConnectionPrompt? {
        switch self {
        case .connected: return nil
        case .expired: return ConnectionPrompt(.codex, "expired", actionKey: "action.recheck")
        // 연결 전과 권한 거부는 키체인을 거치지 않는 Codex에서 생기지 않는다.
        // 생기더라도 조치할 길이 없는 화면을 만들지 않게 로그인 안내로 둔다.
        case .notLoggedIn, .notConnected, .accessDenied:
            return ConnectionPrompt(.codex, "notLoggedIn", actionKey: "action.recheck")
        }
    }

    /// 조회 결과를 받은 뒤의 상태.
    public func next(on event: ConnectionEvent) -> Connection {
        switch event {
        case .fetched: return .connected
        case .notFound: return .notLoggedIn
        case .denied: return .accessDenied
        case .unauthorized: return .expired
        case .needsConsent:
            switch self {
            case .connected, .expired:
                // 연결했던 적이 있다. Claude Code가 토큰을 갱신해 새 항목을 읽을 허락이 필요하다.
                // 첫 연결 안내를 띄우면 사용자는 연결이 풀린 이유를 알 수 없다.
                return .expired
            case .accessDenied:
                // 거부 안내는 사용자가 다시 시도할 때까지 유지한다. 자동 조회가 덮어쓰면
                // 방금 거부한 이유가 화면에서 사라진다.
                return .accessDenied
            case .notConnected, .notLoggedIn:
                return .notConnected
            }
        }
    }
}

/// 연결 상태를 바꾸는 조회 결과.
///
/// 요청 제한과 네트워크 오류는 연결 문제가 아니므로 여기에 없다. 연결 상태를 그대로 둔다.
public enum ConnectionEvent: Equatable, Sendable {
    /// 사용량을 받았다.
    case fetched
    /// 자격증명이 없다. Codex는 ChatGPT 로그인 토큰이 없는 경우도 여기에 든다.
    case notFound
    /// 키체인 창에서 거부했다.
    case denied
    /// 창 없이 읽으려 했으나 사용자 허락이 필요하다.
    case needsConsent
    /// 서버가 토큰을 거부했다 (401, 403).
    case unauthorized
}

/// 연결 안내 화면의 문구 키.
public struct ConnectionPrompt: Equatable, Sendable {
    public let titleKey: String
    public let messageKey: String
    public let actionKey: String

    init(_ provider: Provider, _ state: String, actionKey: String) {
        self.titleKey = "connection.\(provider.rawValue).\(state).title"
        self.messageKey = "connection.\(provider.rawValue).\(state).message"
        self.actionKey = actionKey
    }
}
