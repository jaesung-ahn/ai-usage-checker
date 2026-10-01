import Foundation
import Security

/// 토큰을 읽지 못한 이유. 화면 안내가 달라진다.
enum TokenError: Error {
    /// 자격증명이 없다. Claude는 파일과 키체인 어디에도 없는 경우, Codex는 ChatGPT 토큰이 없는 경우다.
    case notFound
    /// 키체인 접근이 거부되었다.
    case denied
    /// 창 없이 읽으려 했으나 사용자 허락이 필요하다.
    case needsConsent
}

/// Claude Code가 로그인 시 저장해 둔 OAuth 토큰을 읽는다.
///
/// 별도의 API 키를 만들지 않고, 내장 `/usage`가 쓰는 것과 같은 토큰을 재사용한다.
/// 토큰은 메모리에만 두고 로그나 파일로 내보내지 않는다.
///
/// 키체인 접근은 권한 창을 띄울 수 있다. 사용자가 요청한 조회(`interactive`)에서만 창을 허용한다.
final class TokenStore {
    private let credentialsFile: URL
    private let service = "Claude Code-credentials"

    private var cached: String?
    private var reads = 0

    init(credentialsFile: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/.credentials.json")) {
        self.credentialsFile = credentialsFile
    }

    func accessToken(interactive: Bool) -> Result<String, TokenError> {
        reads += 1

        if let cached {
            Log.auth.debug("token: cache hit (read #\(self.reads, privacy: .public))")
            return .success(cached)
        }

        if let token = readFromFile() {
            Log.auth.info("token: read from file (read #\(self.reads, privacy: .public))")
            cached = token
            return .success(token)
        }

        Log.auth.info("token: querying keychain (read #\(self.reads, privacy: .public), interactive: \(interactive, privacy: .public))")
        let result = readFromKeychain(interactive: interactive)
        if case .success(let token) = result {
            Log.auth.info("token: read from keychain")
            cached = token
        }
        return result
    }

    /// 401을 받으면 캐시를 버린다. Claude Code가 토큰을 갱신했을 수 있다.
    func invalidate() {
        cached = nil
    }

    private func readFromFile() -> String? {
        guard let data = try? Data(contentsOf: credentialsFile) else { return nil }
        return Self.accessToken(fromJSON: data)
    }

    private func readFromKeychain(interactive: Bool) -> Result<String, TokenError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        // Claude Code의 항목은 구형 파일 기반 키체인에 있다. 이 키체인에는
        // `kSecUseAuthenticationUIFail`이 적용되지 않아 창이 그대로 뜬다(2026-09-28 실측).
        // 구형 키체인 전용 API로 창을 막는다. 프로세스 전역 설정이므로 조회 직후 되돌린다.
        if !interactive { SecKeychainSetUserInteractionAllowed(false) }
        defer { if !interactive { SecKeychainSetUserInteractionAllowed(true) } }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let token = Self.accessToken(fromJSON: data) else {
                // 항목은 있으나 토큰이 없다. 로그인이 끝나지 않은 상태로 본다.
                return .failure(.notFound)
            }
            return .success(token)
        case errSecItemNotFound:
            Log.auth.info("token: keychain item not found")
            return .failure(.notFound)
        case _ where !interactive:
            // 창을 막았으므로 거부가 아니라 아직 허락받지 않은 상태다.
            Log.auth.info("token: keychain needs consent (status \(status, privacy: .public))")
            return .failure(.needsConsent)
        default:
            // 거부, 취소, 잠김을 구분하지 않는다. 사용자가 할 조치가 같다.
            Log.auth.error("token: keychain query failed (status \(status, privacy: .public))")
            return .failure(.denied)
        }
    }

    /// 자격증명은 `claudeAiOauth` 아래에 있거나 최상위에 있다. 둘 다 받는다.
    static func accessToken(fromJSON data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any]
        else { return nil }

        let container = (root["claudeAiOauth"] as? [String: Any]) ?? root
        guard let token = container["accessToken"] as? String, !token.isEmpty else { return nil }
        return token
    }
}
