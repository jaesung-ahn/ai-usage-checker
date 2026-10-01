import Foundation
import UsageCore

/// Claude OAuth usage 엔드포인트 호출.
///
/// 응답 본문과 토큰은 로그에 남기지 않는다.
struct ClaudeClient {
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let session: URLSession
    private let tokenStore: TokenStore

    init(tokenStore: TokenStore = TokenStore(), session: URLSession = .shared) {
        self.tokenStore = tokenStore
        self.session = session
    }

    func forgetCredentials() {
        tokenStore.invalidate()
    }

    /// `interactive`가 참일 때만 키체인 권한 창을 띄울 수 있다.
    func fetch(now: Date = Date(), interactive: Bool) async throws -> UsageReading {
        let token: String
        switch tokenStore.accessToken(interactive: interactive) {
        case .success(let value): token = value
        case .failure(let reason): throw UsageClientError.credentials(reason)
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        let json: [String: Any]
        do {
            json = try UsageResponse.json(data: data, response: response)
        } catch UsageClientError.unauthorized {
            // Claude Code가 토큰을 갱신했을 수 있다. 다음 시도에서 다시 읽는다.
            tokenStore.invalidate()
            throw UsageClientError.unauthorized
        }

        return try UsageResponse.validated(ClaudeSource.normalize(json: json, observedAt: now))
    }
}
