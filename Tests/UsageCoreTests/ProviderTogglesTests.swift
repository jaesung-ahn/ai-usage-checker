import XCTest
@testable import UsageCore

final class ProviderTogglesTests: XCTestCase {
    func testFirstLaunchEnablesClaudeOnly() {
        let toggles = ProviderToggles(stored: nil)
        XCTAssertTrue(toggles.isEnabled(.claude))
        XCTAssertFalse(toggles.isEnabled(.codex), "Codex는 토글이 연결 동의다. 사용자가 켜야 한다")
    }

    func testStoredEmptyListMeansAllOff() {
        XCTAssertTrue(ProviderToggles(stored: []).enabled.isEmpty, "모두 꺼둔 상태를 기본값으로 되돌리지 않는다")
    }

    func testUnknownStoredNamesAreDropped() {
        let toggles = ProviderToggles(stored: ["codex", "retired"])
        XCTAssertEqual(toggles.enabled, [.codex])
    }

    func testStoredRoundTripsInFixedOrder() {
        let toggles = ProviderToggles(enabled: [.codex, .claude])
        XCTAssertEqual(toggles.stored, ["claude", "codex"])
        XCTAssertEqual(ProviderToggles(stored: toggles.stored), toggles)
    }

    func testEachEnabledProviderGetsItsOwnItem() {
        let toggles = ProviderToggles(enabled: [.codex, .claude])
        XCTAssertEqual(toggles.menuBarEntries, [.provider(.claude), .provider(.codex)])
    }

    func testAllOffLeavesAppIcon() {
        var toggles = ProviderToggles.default
        toggles.set(.claude, enabled: false)

        XCTAssertEqual(toggles.menuBarEntries, [.appIcon], "진입점이 없으면 다시 켜거나 종료할 수 없다")
    }

    func testAppIconDisappearsWhenAnyProviderIsOn() {
        var toggles = ProviderToggles(enabled: [])
        toggles.set(.codex, enabled: true)

        XCTAssertEqual(toggles.menuBarEntries, [.provider(.codex)])
    }

    func testProviderKeysExistInLocale() throws {
        let url = Fixtures.packageRoot.appendingPathComponent("locales/ko.json")
        let table = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String]
        )
        for provider in Provider.allCases {
            for key in [provider.titleKey, provider.nameKey, provider.shortKey] {
                XCTAssertNotNil(table[key], "\(key)가 없으면 화면에 키가 그대로 보인다")
            }
        }
    }
}
