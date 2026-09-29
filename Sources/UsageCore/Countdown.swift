import Foundation

/// 리셋까지 남은 시간.
///
/// `isStale`은 리셋 시각이 이미 지났다는 뜻이다. 데이터가 갱신되지 않았다는 신호이므로
/// 호출자는 사용률 값을 그대로 신뢰하지 않아야 한다.
public struct Countdown: Equatable, Sendable {
    public let remaining: TimeInterval
    public let isStale: Bool
}

/// 리셋 시각이 없으면 카운트다운을 만들지 않는다.
public func countdown(resetsAt: Date?, now: Date) -> Countdown? {
    guard let resetsAt else { return nil }
    let raw = resetsAt.timeIntervalSince(now)
    return Countdown(remaining: max(0, raw), isStale: raw < 0)
}

/// 팝오버 형식. 초까지 표시하고 1초마다 갱신한다. 메뉴바에는 카운트다운을 두지 않는다.
public func formatCountdown(_ countdown: Countdown) -> String {
    let total = Int(countdown.remaining)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    return "\(hours)h \(minutes)m \(seconds)s"
}

/// 요청 제한 대기 형식. 남은 시간을 올림해 0초로 보이는 순간을 만들지 않는다.
public func formatRetryDelay(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded(.up))
    let minutes = total / 60
    let remainder = total % 60
    return minutes > 0 ? "\(minutes)m \(remainder)s" : "\(remainder)s"
}
