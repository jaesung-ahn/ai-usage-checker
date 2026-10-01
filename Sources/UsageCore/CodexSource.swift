import Foundation

/// Codex `wham/usage` 응답을 내부 모델로 정규화한다.
///
/// 상세는 docs/spec/codex-usage-api.md 참조.
/// 응답에 든 계정 식별자(`user_id`, `account_id`, `email`)는 읽지 않는다.
public enum CodexSource {
    public static func normalize(json: [String: Any], observedAt: Date) -> UsageReading {
        var windows = windows(in: json["rate_limit"], scope: nil)

        if let additional = json["additional_rate_limits"] as? [[String: Any]] {
            for limit in additional {
                // 이름이 없으면 무엇의 한도인지 알 수 없다.
                guard let name = limit["limit_name"] as? String, !name.isEmpty else { continue }
                windows += self.windows(in: limit["rate_limit"], scope: name)
            }
        }

        return UsageReading(provider: .codex, observedAt: observedAt, windows: windows)
    }

    /// `primary_window`, `secondary_window`라는 위치에 의미를 두지 않는다.
    ///
    /// 2026-08-23 로컬 세션 로그에는 `primary`가 7일 창이었다. 창은 `limit_window_seconds`로 구분한다.
    private static func windows(in rateLimit: Any?, scope: String?) -> [UsageWindow] {
        guard let rateLimit = rateLimit as? [String: Any] else { return [] }
        return ["primary_window", "secondary_window"].compactMap {
            window(from: rateLimit[$0], scope: scope)
        }
    }

    private static func window(from value: Any?, scope: String?) -> UsageWindow? {
        guard
            let dict = value as? [String: Any],
            let percent = Parse.number(dict["used_percent"]),
            // 길이를 모르면 어느 창인지 알 수 없다.
            let seconds = Parse.number(dict["limit_window_seconds"]), seconds > 0
        else { return nil }

        return UsageWindow(
            scope: scope,
            length: WindowLength(seconds: Int(seconds)),
            percent: percent,
            resetsAt: Parse.epochDate(dict["reset_at"])
        )
    }
}
