import XCTest
@testable import UsageCore

final class UsageReadingTests: XCTestCase {
    private let observedAt = Date(timeIntervalSince1970: 1_790_000_000)

    private func reading(_ windows: [UsageWindow]) -> UsageReading {
        UsageReading(provider: .codex, observedAt: observedAt, windows: windows)
    }

    func testOrderDoesNotDependOnResponseOrder() {
        let hour = WindowLength(seconds: 3_600)
        let result = reading([
            UsageWindow(scope: "Spark", length: .sevenDays, percent: 1, resetsAt: nil),
            UsageWindow(length: .sevenDays, percent: 2, resetsAt: nil),
            UsageWindow(scope: "Atlas", length: .fiveHours, percent: 3, resetsAt: nil),
            UsageWindow(scope: "Spark", length: .fiveHours, percent: 4, resetsAt: nil),
            UsageWindow(length: .fiveHours, percent: 5, resetsAt: nil),
            UsageWindow(length: hour, percent: 6, resetsAt: nil),
        ])

        XCTAssertEqual(
            result.windows.map(\.id),
            [
                UsageWindow.ID(scope: nil, length: hour),
                UsageWindow.ID(scope: nil, length: .fiveHours),
                UsageWindow.ID(scope: nil, length: .sevenDays),
                UsageWindow.ID(scope: "Atlas", length: .fiveHours),
                UsageWindow.ID(scope: "Spark", length: .fiveHours),
                UsageWindow.ID(scope: "Spark", length: .sevenDays),
            ],
            "전체 창을 길이순으로 먼저, 범위가 있는 창을 이름순으로 둔다"
        )
    }

    func testDuplicateWindowKeepsHigherPercent() {
        let result = reading([
            UsageWindow(length: .fiveHours, percent: 80, resetsAt: nil),
            UsageWindow(length: .fiveHours, percent: 10, resetsAt: nil),
        ])

        XCTAssertEqual(result.windows.count, 1, "같은 창이 두 행으로 보이지 않는다")
        XCTAssertEqual(result.window(.fiveHours)?.percent, 80, "낮은 쪽을 보여주면 임박해도 안전해 보인다")
    }

    func testLookupDistinguishesScope() {
        let result = reading([
            UsageWindow(scope: "Fable", length: .sevenDays, percent: 23, resetsAt: nil),
        ])

        XCTAssertNil(result.window(.sevenDays))
        XCTAssertEqual(result.window(.sevenDays, scope: "Fable")?.percent, 23)
    }

    func testNoWindowsIsEmpty() {
        XCTAssertTrue(reading([]).isEmpty)
    }
}
