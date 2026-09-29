import XCTest
@testable import UsageCore

final class CountdownTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testNilResetProducesNoCountdown() {
        XCTAssertNil(countdown(resetsAt: nil, now: now))
    }

    func testRemainingIsClampedAndMarkedStale() {
        let past = countdown(resetsAt: now.addingTimeInterval(-60), now: now)
        XCTAssertEqual(past?.remaining, 0)
        XCTAssertEqual(past?.isStale, true)
    }

    func testFutureResetIsNotStale() {
        let future = countdown(resetsAt: now.addingTimeInterval(3661), now: now)
        XCTAssertEqual(future?.remaining, 3661)
        XCTAssertEqual(future?.isStale, false)
    }

    func testShowsSeconds() {
        let c = Countdown(remaining: 3661, isStale: false)
        XCTAssertEqual(formatCountdown(c), "1h 1m 1s")
    }

    // MARK: - 요청 제한 대기

    func testRetryDelayRoundsUpSoItNeverShowsZero() {
        XCTAssertEqual(formatRetryDelay(0.2), "1s")
    }

    func testRetryDelayUnderAMinuteShowsSecondsOnly() {
        XCTAssertEqual(formatRetryDelay(59), "59s")
    }

    func testRetryDelayShowsMinutesAndSeconds() {
        XCTAssertEqual(formatRetryDelay(60), "1m 0s")
        XCTAssertEqual(formatRetryDelay(125), "2m 5s")
    }
}
