import XCTest
@testable import UsageCore

final class ConnectionTests: XCTestCase {
    private let problems: [Connection] = [.notConnected, .notLoggedIn, .accessDenied, .expired]

    func testConnectedHasNoPrompt() {
        XCTAssertNil(Connection.connected.prompt)
    }

    func testEveryProblemOffersAnAction() {
        for state in problems {
            XCTAssertNotNil(state.prompt, "\(state)에서 복구할 방법이 화면에 있어야 한다")
        }
    }

    func testPromptTextExistsInLocale() throws {
        let url = Fixtures.packageRoot.appendingPathComponent("locales/ko.json")
        let table = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String]
        )

        for state in problems {
            let prompt = try XCTUnwrap(state.prompt)
            for key in [prompt.titleKey, prompt.messageKey, prompt.actionKey] {
                XCTAssertNotNil(table[key], "\(key)가 없으면 화면에 키가 그대로 보인다")
            }
        }
    }
}
