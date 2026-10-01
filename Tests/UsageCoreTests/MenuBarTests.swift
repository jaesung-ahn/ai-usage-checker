import XCTest
@testable import UsageCore

final class MenuBarTests: XCTestCase {
    private func reading(
        _ provider: Provider = .claude,
        session: Double?,
        weekly: Double?
    ) -> UsageReading {
        var windows = [UsageWindow(scope: "Fable", length: .sevenDays, percent: 23, resetsAt: nil)]
        if let session { windows.append(UsageWindow(length: .fiveHours, percent: session, resetsAt: nil)) }
        if let weekly { windows.append(UsageWindow(length: .sevenDays, percent: weekly, resetsAt: nil)) }
        return UsageReading(
            provider: provider,
            observedAt: Date(timeIntervalSince1970: 1_790_000_000),
            windows: windows
        )
    }

    func testShowsBothWindowsInOrder() {
        let items = menuBarItems(reading: reading(session: 30, weekly: 18), thresholds: .default)

        XCTAssertEqual(items.map(\.labelKey), ["menubar.session", "menubar.weekly"])
        XCTAssertEqual(items.map(\.percent), [30, 18])
    }

    func testEachItemGetsItsOwnLevel() {
        // 5시간이 안전해도 7일이 위험하면 그 사실이 드러나야 한다.
        let items = menuBarItems(reading: reading(session: 10, weekly: 90), thresholds: .default)

        XCTAssertEqual(items[0].level, .safe)
        XCTAssertEqual(items[1].level, .danger)
    }

    func testScopedPoolsAreNotShown() {
        let items = menuBarItems(reading: reading(session: 30, weekly: 18), thresholds: .default)
        XCTAssertEqual(items.count, 2, "개수가 정해지지 않아 메뉴바 폭을 예측할 수 없다")
    }

    func testMissingReadingKeepsSlots() {
        let items = menuBarItems(reading: nil, thresholds: .default)

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { $0.percent == nil && $0.level == nil })
    }

    func testMissingPoolIsNilNotZero() {
        let items = menuBarItems(reading: reading(session: nil, weekly: 18), thresholds: .default)

        XCTAssertNil(items[0].percent, "값 없음과 0%는 다른 상태다")
        XCTAssertEqual(items[1].percent, 18)
    }

    /// Codex는 5시간 창 없이 7일 창만 보낸 적이 있다. 자리는 그대로 두고 값만 비운다.
    func testProviderWithoutSessionWindowKeepsSlot() {
        let items = menuBarItems(reading: reading(.codex, session: nil, weekly: 40), thresholds: .default)

        XCTAssertEqual(items.map(\.labelKey), ["menubar.session", "menubar.weekly"])
        XCTAssertNil(items[0].percent)
        XCTAssertEqual(items[1].percent, 40)
    }

    func testScopedSevenDayWindowIsNotTakenAsWeekly() {
        // 범위가 있는 7일 창은 공급자 전체의 7일 창이 아니다.
        let items = menuBarItems(reading: reading(session: 30, weekly: nil), thresholds: .default)
        XCTAssertNil(items[1].percent)
    }
}
