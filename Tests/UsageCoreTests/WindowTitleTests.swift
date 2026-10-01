import XCTest
@testable import UsageCore

final class WindowTitleTests: XCTestCase {
    private var strings: Strings!

    override func setUpWithError() throws {
        strings = try Strings(contentsOf: Fixtures.packageRoot.appendingPathComponent("locales/ko.json"))
    }

    private func title(_ length: WindowLength, scope: String? = nil) -> String {
        windowTitle(UsageWindow(scope: scope, length: length, percent: 0, resetsAt: nil), strings: strings)
    }

    func testKnownWindowsKeepTheirTitles() {
        XCTAssertEqual(title(.fiveHours), "5시간 사용률")
        XCTAssertEqual(title(.sevenDays), "7일 사용률")
        XCTAssertEqual(title(.sevenDays, scope: "Fable"), "Fable (주간)")
    }

    func testOtherLengthsAreNamedByLength() {
        XCTAssertEqual(title(WindowLength(seconds: 3_600)), "1시간 사용률")
        XCTAssertEqual(title(WindowLength(seconds: 2_592_000)), "30일 사용률")
        XCTAssertEqual(title(WindowLength(seconds: 5_400)), "90분 사용률")
    }

    func testScopedWindowOfOtherLengthShowsBoth() {
        XCTAssertEqual(title(.fiveHours, scope: "Spark"), "Spark (5시간)")
    }

    func testTitlesNeverShowRawKeys() {
        let lengths = [.fiveHours, .sevenDays, WindowLength(seconds: 3_600), WindowLength(seconds: 5_400)]
        for scope in [nil, "Spark"] as [String?] {
            for length in lengths {
                let text = title(length, scope: scope)
                XCTAssertFalse(text.contains("pool.") || text.contains("length."), "\(text): locales에 키가 없다")
                XCTAssertFalse(text.contains("{"), "\(text): 치환되지 않은 자리가 남았다")
            }
        }
    }
}
