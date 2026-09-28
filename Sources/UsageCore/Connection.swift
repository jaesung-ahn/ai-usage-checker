import Foundation

/// Claude Code 로그인 정보에 대한 연결 상태.
///
/// 키체인 접근은 macOS 권한 창을 띄운다. 창은 사용자가 이 상태의 안내 버튼을
/// 눌렀을 때만 뜨게 한다.
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

    /// 사용자 조치가 필요할 때의 안내. 연결되어 있으면 `nil`이다.
    public var prompt: ConnectionPrompt? {
        switch self {
        case .connected: return nil
        case .notConnected: return ConnectionPrompt(state: "notConnected", actionKey: "action.connect")
        case .notLoggedIn: return ConnectionPrompt(state: "notLoggedIn", actionKey: "action.recheck")
        case .accessDenied: return ConnectionPrompt(state: "accessDenied", actionKey: "action.retry")
        case .expired: return ConnectionPrompt(state: "expired", actionKey: "action.reconnect")
        }
    }
}

/// 연결 안내 화면의 문구 키.
public struct ConnectionPrompt: Equatable, Sendable {
    public let titleKey: String
    public let messageKey: String
    public let actionKey: String

    init(state: String, actionKey: String) {
        self.titleKey = "connection.\(state).title"
        self.messageKey = "connection.\(state).message"
        self.actionKey = actionKey
    }
}
