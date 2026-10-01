import XCTest
@testable import UsageCore

final class ClaudeSourceTests: XCTestCase {
    private let observedAt = Date(timeIntervalSince1970: 1_790_000_000)

    func testNormalizesCapturedFixture() throws {
        let json = try Fixtures.json("usage-response.json")
        let reading = ClaudeSource.normalize(json: json, observedAt: observedAt)

        XCTAssertEqual(reading.window(.fiveHours)?.percent, 55)
        XCTAssertEqual(reading.window(.sevenDays)?.percent, 18)
    }

    func testExtractsScopedModelPool() throws {
        let json = try Fixtures.json("usage-response.json")
        let reading = ClaudeSource.normalize(json: json, observedAt: observedAt)

        let scoped = reading.windows.filter { $0.scope != nil }
        XCTAssertEqual(scoped.count, 1)
        XCTAssertEqual(scoped.first?.scope, "Fable")
        XCTAssertEqual(scoped.first?.length, .sevenDays)
        XCTAssertEqual(scoped.first?.percent, 23)
    }

    func testMarksProvider() throws {
        let json = try Fixtures.json("usage-response.json")
        XCTAssertEqual(ClaudeSource.normalize(json: json, observedAt: observedAt).provider, .claude)
    }

    func testParsesFractionalIsoDates() throws {
        let json = try Fixtures.json("usage-response.json")
        let reading = ClaudeSource.normalize(json: json, observedAt: observedAt)

        let resetsAt = try XCTUnwrap(reading.window(.fiveHours)?.resetsAt)
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 22
        components.hour = 11
        components.minute = 40
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let expected = try XCTUnwrap(calendar.date(from: components))

        XCTAssertEqual(resetsAt.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testLimitsSupersedeTopLevelKeys() throws {
        // 신형 요금제에서는 top-level seven_day_* 가 전부 null이다. 실측으로 확인했다.
        let json = try Fixtures.json("usage-response.json")
        XCTAssertTrue(json["seven_day_sonnet"] is NSNull)

        let reading = ClaudeSource.normalize(json: json, observedAt: observedAt)
        XCTAssertEqual(reading.windows.compactMap(\.scope), ["Fable"])
    }

    func testFallsBackToTopLevelWhenLimitsAbsent() throws {
        let json = try Fixtures.json("usage-response-legacy.json")
        let reading = ClaudeSource.normalize(json: json, observedAt: observedAt)

        XCTAssertEqual(reading.window(.fiveHours)?.percent, 55)
        XCTAssertEqual(reading.window(.sevenDays)?.percent, 18)
        XCTAssertEqual(reading.windows.compactMap(\.scope), ["sonnet"])
    }

    func testUnknownKindIsIgnored() {
        let json: [String: Any] = [
            "limits": [
                ["kind": "session", "percent": 40, "resets_at": "2026-09-22T11:40:00.199652+00:00"],
                ["kind": "some_future_kind", "percent": 99],
            ]
        ]
        let reading = ClaudeSource.normalize(json: json, observedAt: observedAt)

        XCTAssertEqual(reading.window(.fiveHours)?.percent, 40)
        XCTAssertNil(reading.window(.sevenDays))
        XCTAssertEqual(reading.windows.count, 1)
    }

    func testScopedPoolWithoutNameIsSkipped() {
        let json: [String: Any] = [
            "limits": [
                ["kind": "weekly_scoped", "percent": 23, "scope": NSNull()],
            ]
        ]
        let reading = ClaudeSource.normalize(json: json, observedAt: observedAt)
        XCTAssertTrue(reading.isEmpty, "무엇의 한도인지 알 수 없으면 표시하지 않는다")
    }

    // MARK: - 빈 응답

    func testCapturedFixtureIsNotEmpty() throws {
        let json = try Fixtures.json("usage-response.json")
        XCTAssertFalse(ClaudeSource.normalize(json: json, observedAt: observedAt).isEmpty)
    }

    /// 응답 형태가 바뀌어 아는 키가 하나도 없으면 성공으로 받지 않는다.
    func testResponseWithOnlyUnknownKeysIsEmpty() {
        let json: [String: Any] = ["something_new": ["utilization": 10]]
        XCTAssertTrue(ClaudeSource.normalize(json: json, observedAt: observedAt).isEmpty)
    }

    func testAllNullPoolsAreEmpty() {
        let json: [String: Any] = ["five_hour": NSNull(), "seven_day": NSNull()]
        XCTAssertTrue(ClaudeSource.normalize(json: json, observedAt: observedAt).isEmpty)
    }

    func testScopedPoolAloneIsNotEmpty() {
        let json: [String: Any] = ["limits": [[
            "kind": "weekly_scoped",
            "percent": 5,
            "scope": ["model": ["display_name": "Fable"]],
        ]]]
        XCTAssertFalse(ClaudeSource.normalize(json: json, observedAt: observedAt).isEmpty)
    }
}
