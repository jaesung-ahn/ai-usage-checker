import Foundation

/// 한도가 적용되는 시간 창의 길이.
///
/// 공급자마다 창을 가리키는 표현이 다르다. Claude는 `kind`, Codex는 응답 안의 위치를 쓰며
/// Codex의 위치는 의미가 고정되어 있지 않다. 길이는 둘 모두에서 같은 뜻이므로 길이로 구분한다.
public struct WindowLength: Hashable, Comparable, Sendable {
    public static let fiveHours = WindowLength(seconds: 18_000)
    public static let sevenDays = WindowLength(seconds: 604_800)

    public let seconds: Int

    public init(seconds: Int) {
        self.seconds = seconds
    }

    public static func < (lhs: WindowLength, rhs: WindowLength) -> Bool {
        lhs.seconds < rhs.seconds
    }
}

/// 사용량 창 하나. 5시간 창, 7일 창, 모델별 주간 풀, 추가 한도가 모두 이 형태다.
///
/// 창은 범위와 길이로 식별한다.
public struct UsageWindow: Equatable, Sendable, Identifiable {
    public struct ID: Hashable, Sendable {
        public let scope: String?
        public let length: WindowLength
    }

    /// 한도가 적용되는 범위. `nil`이면 공급자 전체, 있으면 모델이나 추가 한도의 이름이다.
    public let scope: String?
    public let length: WindowLength
    public let percent: Double
    public let resetsAt: Date?

    public init(scope: String? = nil, length: WindowLength, percent: Double, resetsAt: Date?) {
        self.scope = scope
        self.length = length
        self.percent = percent
        self.resetsAt = resetsAt
    }

    public var id: ID { ID(scope: scope, length: length) }
}

/// 한 시점의 관측. 공급자마다 다른 응답이 모두 이 모델로 정규화된다.
///
/// 값이 없는 창은 목록에 넣지 않는다. 0%로 대체하지 않는다. 0%와 "데이터 없음"은 다른 상태다.
public struct UsageReading: Equatable, Sendable {
    public let provider: Provider
    public let observedAt: Date
    /// 공급자 전체 창을 길이순으로, 그 뒤에 범위가 있는 창을 이름순으로 둔다.
    public let windows: [UsageWindow]

    /// 응답 순서에 의존하면 행 순서가 동기화마다 바뀐다. 순서는 여기서 고정한다.
    ///
    /// 같은 창이 두 번 오면 사용률이 높은 쪽을 남긴다. 낮은 쪽을 보여주면 한도가 임박해도
    /// 안전해 보인다.
    public init(provider: Provider, observedAt: Date, windows: [UsageWindow]) {
        var byID: [UsageWindow.ID: UsageWindow] = [:]
        for window in windows {
            if let kept = byID[window.id], kept.percent >= window.percent { continue }
            byID[window.id] = window
        }

        self.provider = provider
        self.observedAt = observedAt
        self.windows = byID.values.sorted(by: Self.displayOrder)
    }

    /// 범위와 길이로 창을 찾는다. 없으면 `nil`이다.
    public func window(_ length: WindowLength, scope: String? = nil) -> UsageWindow? {
        windows.first { $0.length == length && $0.scope == scope }
    }

    /// 아는 창이 하나도 없다. 응답 형태가 바뀌어 아무것도 읽지 못한 경우다.
    /// 성공으로 받으면 빈 화면이 현재 값처럼 보인다.
    public var isEmpty: Bool {
        windows.isEmpty
    }

    private static func displayOrder(_ lhs: UsageWindow, _ rhs: UsageWindow) -> Bool {
        switch (lhs.scope, rhs.scope) {
        case (nil, nil):
            return lhs.length < rhs.length
        case (nil, _):
            return true
        case (_, nil):
            return false
        case let (left?, right?):
            return left == right ? lhs.length < rhs.length : left < right
        }
    }
}
