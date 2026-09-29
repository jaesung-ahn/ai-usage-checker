import Foundation

/// 사용량 풀 하나. 5시간 창, 7일 창, 모델별 주간 풀이 모두 이 형태다.
public struct Pool: Equatable, Sendable {
    public let name: String
    public let percent: Double
    public let resetsAt: Date?

    public init(name: String, percent: Double, resetsAt: Date?) {
        self.name = name
        self.percent = percent
        self.resetsAt = resetsAt
    }
}

/// 한 시점의 관측. 응답의 두 표현이 모두 이 모델로 정규화된다.
///
/// 값이 없는 풀은 `nil`이다. 0%로 대체하지 않는다. 0%와 "데이터 없음"은 다른 상태다.
public struct UsageReading: Equatable, Sendable {
    public let observedAt: Date
    public let session: Pool?
    public let weeklyAll: Pool?
    public let weeklyScoped: [Pool]

    public init(
        observedAt: Date,
        session: Pool?,
        weeklyAll: Pool?,
        weeklyScoped: [Pool]
    ) {
        self.observedAt = observedAt
        self.session = session
        self.weeklyAll = weeklyAll
        self.weeklyScoped = weeklyScoped
    }

    /// 아는 풀이 하나도 없다. 응답 형태가 바뀌어 아무것도 읽지 못한 경우다.
    /// 성공으로 받으면 빈 화면이 현재 값처럼 보인다.
    public var isEmpty: Bool {
        session == nil && weeklyAll == nil && weeklyScoped.isEmpty
    }
}
