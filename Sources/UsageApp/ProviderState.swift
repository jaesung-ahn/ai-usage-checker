import Foundation
import UsageCore

/// 사용량 조회 결과. 자격증명 문제는 `Connection`이 따로 다룬다.
enum LoadState: Equatable {
    case idle
    case ok
    case rateLimited
    case failed
}

/// 공급자 하나의 조회 상태.
///
/// 연결 상태, 요청 간격과 백오프를 공급자마다 따로 둔다. 한쪽의 429가 다른 쪽 조회를 막지 않는다.
@MainActor
final class ProviderState: ObservableObject {
    let provider: Provider

    @Published private(set) var reading: UsageReading?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var connection: Connection

    let strings: Strings

    private let client: UsageProviding
    private let defaults: UserDefaults

    /// 연타와 429 이후 즉시 재시도를 막는다.
    private var gate = RequestGate()
    /// 공급자를 끌 때마다 바뀐다. 끄기 전에 보낸 요청의 응답은 버린다.
    private var generation = 0

    /// 사용자가 Claude 연결을 해제했는지. 해제했으면 "항상 허용" 상태여도 스스로 연결하지 않는다.
    private static let claudeDisconnectedKey = "disconnectedByUser"

    init(provider: Provider, client: UsageProviding, strings: Strings, defaults: UserDefaults) {
        self.provider = provider
        self.client = client
        self.strings = strings
        self.defaults = defaults
        self.connection = Connection.initial(for: provider)
    }

    var prompt: ConnectionPrompt? { connection.prompt(for: provider) }

    /// 연결 해제 버튼을 둘지. Codex는 토글을 끄는 것이 해제다.
    var canDisconnect: Bool { provider == .claude && connection == .connected }

    /// 지금 요청을 보낼 수 있는지. 버튼 비활성화에 쓴다.
    var canRefresh: Bool { gate.canRequest(at: Date()) }

    /// 다음 요청까지 남은 시간. 0이면 바로 보낼 수 있다.
    func cooldown(at now: Date = Date()) -> TimeInterval {
        gate.remainingCooldown(at: now)
    }

    /// 실패해도 마지막 성공 값을 지우지 않는다. 오래된 값이라도 없는 것보다 낫다.
    ///
    /// 키체인 권한 창은 사용자가 버튼을 눌렀을 때(`userInitiated`)만 뜬다.
    /// 시작 시와 타이머 호출은 창 없이 읽고, 허락이 필요하면 연결 안내로 돌아간다.
    func refresh(userInitiated: Bool = false, now: Date = Date()) async {
        guard userInitiated || !isDisconnectedByUser else { return }
        guard gate.canRequest(at: now) else { return }
        gate.recordAttempt(at: now)
        let sent = generation

        let result: Result<UsageReading, Error>
        do {
            result = .success(try await client.fetch(now: now, interactive: userInitiated))
        } catch {
            result = .failure(error)
        }
        guard sent == generation else { return }

        switch result {
        case .success(let value):
            reading = value
            lastUpdated = now
            loadState = .ok
            gate.recordSuccess()
            apply(.fetched)
            if provider == .claude { defaults.removeObject(forKey: Self.claudeDisconnectedKey) }
        case .failure(UsageClientError.credentials(.notFound)):
            apply(.notFound)
        case .failure(UsageClientError.credentials(.denied)):
            apply(.denied)
        case .failure(UsageClientError.credentials(.needsConsent)):
            apply(.needsConsent)
        case .failure(UsageClientError.unauthorized):
            apply(.unauthorized)
        case .failure(UsageClientError.rateLimited(let retryAfter)):
            gate.recordRateLimited(at: now, retryAfter: retryAfter)
            loadState = .rateLimited
        case .failure:
            loadState = .failed
        }
    }

    /// 이 앱이 더 이상 Claude 토큰을 읽지 않게 한다. 다음 실행에서도 연결 버튼을 눌러야 한다.
    ///
    /// macOS의 키체인 권한은 남는다. 안내는 `DisconnectAlert`가 맡는다.
    func disconnect() {
        guard provider == .claude else { return }
        reset(to: .notConnected)
        defaults.set(true, forKey: Self.claudeDisconnectedKey)
    }

    /// 공급자를 껐다. 토큰 읽기를 멈추고 메모리의 토큰과 값을 버린다.
    ///
    /// 요청 간격과 백오프는 남긴다. 껐다 켜는 것으로 429 대기를 건너뛰지 않게 한다.
    func stop() {
        reset(to: Connection.initial(for: provider))
    }

    private func reset(to state: Connection) {
        generation += 1
        client.forgetCredentials()
        reading = nil
        lastUpdated = nil
        loadState = .idle
        connection = state
    }

    /// 상태가 그대로면 대입하지 않는다. 대입만으로도 메뉴바가 다시 그려진다.
    private func apply(_ event: ConnectionEvent) {
        let next = connection.next(on: event)
        if next != connection { connection = next }
    }

    private var isDisconnectedByUser: Bool {
        provider == .claude && defaults.bool(forKey: Self.claudeDisconnectedKey)
    }

    /// 상태 줄에 띄울 안내. 정상이면 표시하지 않는다.
    var notice: String? {
        problemKey.map { strings($0) }
    }

    /// 값이 하나도 없을 때 화면 가운데에 띄울 설명.
    /// 제한에 걸린 상태를 "불러오는 중"으로 보여주면 사실과 다르다.
    var emptyStateMessage: String {
        strings(problemKey ?? "status.loading")
    }

    private var problemKey: String? {
        switch loadState {
        case .idle, .ok: return nil
        case .rateLimited: return "status.rateLimited"
        case .failed: return "status.apiFailed"
        }
    }

    /// 대기 중이면 남은 시간을 문장으로. 아니면 nil.
    func retryMessage(at now: Date = Date()) -> String? {
        let remaining = cooldown(at: now)
        guard remaining > 0 else { return nil }
        return strings("status.retryIn", ["time": formatRetryDelay(remaining)])
    }
}
