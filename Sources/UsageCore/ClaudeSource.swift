import Foundation

/// Claude OAuth usage 응답을 내부 모델로 정규화한다.
///
/// 상세는 docs/spec/usage-api.md 참조.
public enum ClaudeSource {
    private static let sessionKind = "session"
    private static let weeklyAllKind = "weekly_all"
    private static let weeklyScopedKind = "weekly_scoped"

    public static func normalize(json: [String: Any], observedAt: Date) -> UsageReading {
        let windows: [UsageWindow]
        if let limits = json["limits"] as? [[String: Any]], !limits.isEmpty {
            windows = fromLimits(limits)
        } else {
            windows = fromTopLevel(json)
        }
        return UsageReading(provider: .claude, observedAt: observedAt, windows: windows)
    }

    /// `limits`가 있으면 그쪽이 권위를 갖는다.
    ///
    /// 신형 요금제에서는 top-level `seven_day_*` 키가 전부 `null`로 온다. 실측으로 확인했다.
    /// 둘을 병합하면 0%로 표시되는 행이 생긴다.
    private static func fromLimits(_ limits: [[String: Any]]) -> [UsageWindow] {
        var windows: [UsageWindow] = []

        for limit in limits {
            guard let percent = Parse.number(limit["percent"]) else { continue }
            let resetsAt = Parse.isoDate(limit["resets_at"])

            // 알 수 없는 kind는 무시한다. 새 종류가 추가되어도 파싱이 실패하지 않아야 한다.
            switch limit["kind"] as? String {
            case sessionKind:
                windows.append(UsageWindow(length: .fiveHours, percent: percent, resetsAt: resetsAt))
            case weeklyAllKind:
                windows.append(UsageWindow(length: .sevenDays, percent: percent, resetsAt: resetsAt))
            case weeklyScopedKind:
                // 이름이 없으면 행을 만들지 않는다. 무엇의 한도인지 알 수 없다.
                guard let name = modelName(from: limit["scope"]) else { continue }
                windows.append(
                    UsageWindow(scope: name, length: .sevenDays, percent: percent, resetsAt: resetsAt)
                )
            default:
                continue
            }
        }

        return windows
    }

    private static func fromTopLevel(_ json: [String: Any]) -> [UsageWindow] {
        let known: Set<String> = ["seven_day"]
        var windows: [UsageWindow] = []

        if let session = window(length: .fiveHours, from: json["five_hour"]) {
            windows.append(session)
        }
        if let weekly = window(length: .sevenDays, from: json["seven_day"]) {
            windows.append(weekly)
        }

        for (key, value) in json where key.hasPrefix("seven_day_") && !known.contains(key) {
            let slug = String(key.dropFirst("seven_day_".count))
            if let scoped = window(scope: slug, length: .sevenDays, from: value) {
                windows.append(scoped)
            }
        }

        return windows
    }

    private static func window(scope: String? = nil, length: WindowLength, from value: Any?) -> UsageWindow? {
        guard
            let dict = value as? [String: Any],
            let percent = Parse.number(dict["utilization"])
        else { return nil }

        return UsageWindow(
            scope: scope,
            length: length,
            percent: percent,
            resetsAt: Parse.isoDate(dict["resets_at"])
        )
    }

    private static func modelName(from scope: Any?) -> String? {
        guard
            let scope = scope as? [String: Any],
            let model = scope["model"] as? [String: Any],
            let name = model["display_name"] as? String,
            !name.isEmpty
        else { return nil }
        return name
    }
}
