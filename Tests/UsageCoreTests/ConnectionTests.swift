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

    // MARK: - 상태 전이

    private let all: [Connection] = [.notConnected, .notLoggedIn, .accessDenied, .expired, .connected]

    func testFetchConnectsFromAnyState() {
        for state in all {
            XCTAssertEqual(state.next(on: .fetched), .connected, "\(state)")
        }
    }

    func testCredentialAndServerFailuresDecideStateRegardlessOfCurrent() {
        for state in all {
            XCTAssertEqual(state.next(on: .notFound), .notLoggedIn, "\(state)")
            XCTAssertEqual(state.next(on: .denied), .accessDenied, "\(state)")
            XCTAssertEqual(state.next(on: .unauthorized), .expired, "\(state)")
        }
    }

    /// Claude Code가 토큰을 갱신하면 창 없이 읽기가 허락 필요로 실패한다.
    /// 첫 연결 안내가 뜨면 사용자는 연결이 왜 풀렸는지 알 수 없다.
    func testTokenRenewalWhileConnectedShowsExpired() {
        XCTAssertEqual(Connection.connected.next(on: .needsConsent), .expired)
    }

    /// 만료 안내 중 주기 조회가 다시 허락 필요로 실패해도 첫 연결 안내로 돌아가지 않는다.
    func testExpiredStaysExpiredOnPeriodicCheck() {
        XCTAssertEqual(Connection.expired.next(on: .needsConsent), .expired)
    }

    /// 자동 조회가 거부 안내를 덮어쓰면 방금 거부한 이유가 화면에서 사라진다.
    func testAccessDeniedIsNotOverwrittenByPeriodicCheck() {
        XCTAssertEqual(Connection.accessDenied.next(on: .needsConsent), .accessDenied)
    }

    func testNeedsConsentBeforeFirstConnectionAsksToConnect() {
        XCTAssertEqual(Connection.notConnected.next(on: .needsConsent), .notConnected)
        XCTAssertEqual(Connection.notLoggedIn.next(on: .needsConsent), .notConnected)
    }
}
