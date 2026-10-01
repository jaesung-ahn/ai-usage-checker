import Foundation

/// 공급자가 공유하는 값 변환.
///
/// 응답 안에서도 퍼센트가 정수와 실수로 섞여 온다. Codex는 정수로만 준다.
public enum Parse {
    public static func number(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return nil
    }

    /// OAuth 응답은 소수점 이하를 포함한 ISO 8601 문자열을 쓴다.
    /// 예: 2026-09-22T11:40:00.199652+00:00
    public static func isoDate(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        if let date = isoWithFraction.date(from: text) { return date }
        return isoPlain.date(from: text)
    }

    /// Codex 응답은 리셋 시각을 epoch 초 정수로 준다.
    public static func epochDate(_ value: Any?) -> Date? {
        number(value).map { Date(timeIntervalSince1970: $0) }
    }

    private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
