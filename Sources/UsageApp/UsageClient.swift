import Foundation
import UsageCore

enum UsageClientError: Error {
    /// 토큰을 읽지 못했다. 이유에 따라 안내가 달라진다.
    case credentials(TokenError)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case malformedResponse
}

/// OAuth usage 엔드포인트 호출.
///
/// 응답 본문과 토큰은 로그에 남기지 않는다.
struct UsageClient {
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let session: URLSession
    private let tokenStore: TokenStore

    init(tokenStore: TokenStore, session: URLSession = .shared) {
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
        guard let http = response as? HTTPURLResponse else {
            throw UsageClientError.malformedResponse
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            // Claude Code가 토큰을 갱신했을 수 있다. 다음 시도에서 다시 읽는다.
            tokenStore.invalidate()
            throw UsageClientError.unauthorized
        case 429:
            // 서버가 대기 시간을 알려주면 추측보다 그 값이 정확하다.
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw UsageClientError.rateLimited(retryAfter: retryAfter)
        default:
            throw UsageClientError.http(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageClientError.malformedResponse
        }

        let reading = ClaudeSource.normalize(json: json, observedAt: now)
        guard !reading.isEmpty else {
            // 응답 본문은 남기지 않는다. 형태가 바뀌었다는 사실만 기록한다.
            Log.network.error("usage: response has no known windows")
            throw UsageClientError.malformedResponse
        }
        return reading
    }
}
