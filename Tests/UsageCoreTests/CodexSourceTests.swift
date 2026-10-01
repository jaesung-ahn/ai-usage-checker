import XCTest
@testable import UsageCore

final class CodexSourceTests: XCTestCase {
    private let observedAt = Date(timeIntervalSince1970: 1_790_855_000)

    private func window(percent: Int, seconds: Int, resetAt: Int = 1_790_870_825) -> [String: Any] {
        [
            "used_percent": percent,
            "limit_window_seconds": seconds,
            "reset_after_seconds": 100,
            "reset_at": resetAt,
        ]
    }

    func testNormalizesCapturedFixture() throws {
        let json = try Fixtures.json("codex-usage-response.json")
        let reading = CodexSource.normalize(json: json, observedAt: observedAt)

        XCTAssertEqual(reading.provider, .codex)
        XCTAssertEqual(reading.window(.fiveHours)?.percent, 2)
        XCTAssertEqual(reading.window(.sevenDays)?.percent, 0, "0%는 값 없음이 아니다")
        XCTAssertEqual(reading.windows.count, 2)
    }

    func testResetAtIsEpochSeconds() throws {
        let json = try Fixtures.json("codex-usage-response.json")
        let reading = CodexSource.normalize(json: json, observedAt: observedAt)

        XCTAssertEqual(reading.window(.fiveHours)?.resetsAt, Date(timeIntervalSince1970: 1_790_870_825))
        XCTAssertEqual(reading.window(.sevenDays)?.resetsAt, Date(timeIntervalSince1970: 1_791_457_625))
    }

    /// 2026-08-23 로컬 세션 로그에는 primary가 7일 창, secondary가 null이었다.
    func testWindowsAreIdentifiedByLengthNotPosition() {
        let json: [String: Any] = [
            "rate_limit": [
                "primary_window": window(percent: 40, seconds: 604_800),
                "secondary_window": NSNull(),
            ]
        ]
        let reading = CodexSource.normalize(json: json, observedAt: observedAt)

        XCTAssertNil(reading.window(.fiveHours))
        XCTAssertEqual(reading.window(.sevenDays)?.percent, 40)
    }

    func testUnknownLengthIsKept() {
        let json: [String: Any] = [
            "rate_limit": ["primary_window": window(percent: 7, seconds: 3_600)]
        ]
        let reading = CodexSource.normalize(json: json, observedAt: observedAt)

        XCTAssertEqual(reading.window(WindowLength(seconds: 3_600))?.percent, 7, "버리지 않는다")
    }

    func testWindowWithoutPercentOrLengthIsSkipped() {
        var noPercent = window(percent: 0, seconds: 18_000)
        noPercent["used_percent"] = NSNull()
        var noLength = window(percent: 10, seconds: 0)
        noLength.removeValue(forKey: "limit_window_seconds")

        let json: [String: Any] = [
            "rate_limit": ["primary_window": noPercent, "secondary_window": noLength]
        ]
        XCTAssertTrue(CodexSource.normalize(json: json, observedAt: observedAt).isEmpty)
    }

    func testAdditionalLimitsBecomeScopedWindows() {
        let json: [String: Any] = [
            "rate_limit": ["primary_window": window(percent: 2, seconds: 18_000)],
            "additional_rate_limits": [
                [
                    "limit_name": "Spark",
                    "metered_feature": "spark",
                    "rate_limit": [
                        "primary_window": window(percent: 30, seconds: 18_000),
                        "secondary_window": window(percent: 12, seconds: 604_800),
                    ],
                ],
                [
                    "limit_name": "Atlas",
                    "rate_limit": ["primary_window": window(percent: 5, seconds: 604_800)],
                ],
            ],
        ]
        let reading = CodexSource.normalize(json: json, observedAt: observedAt)

        XCTAssertEqual(reading.window(.fiveHours)?.percent, 2)
        XCTAssertEqual(reading.window(.fiveHours, scope: "Spark")?.percent, 30)
        XCTAssertEqual(reading.window(.sevenDays, scope: "Spark")?.percent, 12)
        XCTAssertEqual(reading.windows.compactMap(\.scope), ["Atlas", "Spark", "Spark"], "이름순")
    }

    func testAdditionalLimitWithoutNameIsSkipped() {
        let json: [String: Any] = [
            "additional_rate_limits": [
                ["limit_name": "", "rate_limit": ["primary_window": window(percent: 5, seconds: 18_000)]],
                ["rate_limit": ["primary_window": window(percent: 5, seconds: 18_000)]],
            ]
        ]
        XCTAssertTrue(
            CodexSource.normalize(json: json, observedAt: observedAt).isEmpty,
            "무엇의 한도인지 알 수 없으면 표시하지 않는다"
        )
    }

    // MARK: - 빈 응답

    func testNullRateLimitIsEmpty() {
        let json: [String: Any] = ["rate_limit": NSNull(), "additional_rate_limits": NSNull()]
        XCTAssertTrue(CodexSource.normalize(json: json, observedAt: observedAt).isEmpty)
    }

    func testResponseWithOnlyUnknownKeysIsEmpty() {
        let json: [String: Any] = ["plan_type": "plus", "something_new": ["used_percent": 10]]
        XCTAssertTrue(CodexSource.normalize(json: json, observedAt: observedAt).isEmpty)
    }
}
