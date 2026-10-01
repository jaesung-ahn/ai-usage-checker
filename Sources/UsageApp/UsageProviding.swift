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

/// 사용량을 가져오는 경로. 공급자마다 하나씩 둔다.
///
/// `ProviderState`가 구체 타입에 묶이지 않게 하는 이음매다. 앱 계층 테스트를 붙일 때 이 지점에
/// 대역을 넣는다. 공급자의 조회 방식을 바꿀 때도 이 지점만 바꾼다.
protocol UsageProviding {
    func fetch(now: Date, interactive: Bool) async throws -> UsageReading
    /// 메모리에 든 자격증명을 버린다.
    func forgetCredentials()
}

/// 공급자가 공유하는 응답 처리.
///
/// 응답 본문은 로그에 남기지 않는다.
enum UsageResponse {
    /// 200이면 JSON 객체를, 아니면 상태에 맞는 오류를 낸다.
    static func json(data: Data, response: URLResponse) throws -> [String: Any] {
        guard let http = response as? HTTPURLResponse else {
            throw UsageClientError.malformedResponse
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
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
        return json
    }

    /// 아는 창이 하나도 없으면 성공으로 받지 않는다. 빈 화면이 현재 값처럼 보인다.
    static func validated(_ reading: UsageReading) throws -> UsageReading {
        guard !reading.isEmpty else {
            // 응답 본문은 남기지 않는다. 형태가 바뀌었다는 사실만 기록한다.
            Log.network.error("usage(\(reading.provider.rawValue, privacy: .public)): response has no known windows")
            throw UsageClientError.malformedResponse
        }
        return reading
    }
}

extension ClaudeClient: UsageProviding {}
extension CodexClient: UsageProviding {}
