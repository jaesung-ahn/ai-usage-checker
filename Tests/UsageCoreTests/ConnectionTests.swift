import XCTest
@testable import UsageCore

final class ConnectionTests: XCTestCase {
    private let problems: [Connection] = [.notConnected, .notLoggedIn, .accessDenied, .expired]

    func testConnectedHasNoPrompt() {
        for provider in Provider.allCases {
            XCTAssertNil(Connection.connected.prompt(for: provider), "\(provider)")
        }
    }

    func testEveryProblemOffersAnAction() {
        for provider in Provider.allCases {
            for state in problems {
                XCTAssertNotNil(state.prompt(for: provider), "\(provider) \(state)에서 복구할 방법이 화면에 있어야 한다")
            }
        }
    }

    func testPromptTextExistsInLocale() throws {
        let url = Fixtures.packageRoot.appendingPathComponent("locales/ko.json")
        let table = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String]
        )

        for provider in Provider.allCases {
            for state in problems {
                let prompt = try XCTUnwrap(state.prompt(for: provider))
                for key in [prompt.titleKey, prompt.messageKey, prompt.actionKey] {
                    XCTAssertNotNil(table[key], "\(key)가 없으면 화면에 키가 그대로 보인다")
                }
            }
        }
    }

    func testPromptsAreProviderSpecific() {
        let claude = Connection.notLoggedIn.prompt(for: .claude)
        let codex = Connection.notLoggedIn.prompt(for: .codex)
        XCTAssertNotEqual(claude?.messageKey, codex?.messageKey, "로그인 방법이 공급자마다 다르다")
    }

    /// 앱이 Codex 토큰을 갱신하지 않는다. 다시 연결할 수단이 없으므로 다시 확인만 둔다.
    func testCodexExpiredOnlyRechecks() {
        XCTAssertEqual(Connection.expired.prompt(for: .codex)?.actionKey, "action.recheck")
    }

    // MARK: - 초기 상태

    func testClaudeStartsNotConnected() {
        XCTAssertEqual(Connection.initial(for: .claude), .notConnected, "연결 버튼이 키체인 접근 동의다")
    }

    /// 토글을 켜는 것이 연결 동의다. 연결 버튼을 다시 보여주지 않는다.
    func testCodexStartsWithoutPrompt() {
        XCTAssertNil(Connection.initial(for: .codex).prompt(for: .codex))
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
