import Foundation
import UsageCore

/// Codex에 ChatGPT 계정으로 로그인했을 때 저장되는 자격증명.
struct CodexCredentials {
    let accessToken: String
    let accountID: String?
}

/// Codex가 저장한 `~/.codex/auth.json`을 읽는다. 파일이라 키체인 권한 창이 없다.
///
/// 앱은 이 파일에 쓰지 않는다. 토큰 갱신은 Codex가 한다.
/// 매 조회마다 다시 읽는다. Codex가 갱신한 토큰을 바로 쓰고, 메모리에 토큰을 남기지 않는다.
struct CodexAuthFile {
    let url: URL

    init(url: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/auth.json")) {
        self.url = url
    }

    func read() -> Result<CodexCredentials, TokenError> {
        guard let data = try? Data(contentsOf: url) else {
            Log.auth.info("codex token: auth file not found")
            return .failure(.notFound)
        }
        // API 키 로그인에는 ChatGPT 토큰이 없다. 이 엔드포인트에 쓸 수 없으므로 로그인 안 됨으로 본다.
        guard let credentials = Self.credentials(fromJSON: data) else {
            Log.auth.info("codex token: no ChatGPT token in auth file")
            return .failure(.notFound)
        }
        return .success(credentials)
    }

    static func credentials(fromJSON data: Data) -> CodexCredentials? {
        guard
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let tokens = root["tokens"] as? [String: Any],
            let token = tokens["access_token"] as? String, !token.isEmpty
        else { return nil }

        let accountID = (tokens["account_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return CodexCredentials(accessToken: token, accountID: accountID)
    }
}

/// Codex 사용량 엔드포인트 호출. Codex CLI의 `/usage`가 쓰는 것과 같다.
///
/// 응답 본문, 토큰, 계정 ID는 로그에 남기지 않는다.
struct CodexClient {
    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let session: URLSession
    private let authFile: CodexAuthFile

    init(authFile: CodexAuthFile = CodexAuthFile(), session: URLSession = .shared) {
        self.authFile = authFile
        self.session = session
    }

    /// 토큰을 메모리에 두지 않으므로 버릴 것이 없다.
    func forgetCredentials() {}

    /// 키체인을 거치지 않으므로 `interactive`는 쓰지 않는다.
    func fetch(now: Date = Date(), interactive: Bool) async throws -> UsageReading {
        let credentials: CodexCredentials
        switch authFile.read() {
        case .success(let value): credentials = value
        case .failure(let reason): throw UsageClientError.credentials(reason)
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = credentials.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        let json = try UsageResponse.json(data: data, response: response)
        return try UsageResponse.validated(CodexSource.normalize(json: json, observedAt: now))
    }
}
