import Foundation
import UsageCore

/// 사용량 조회 결과. 자격증명 문제는 `Connection`이 따로 다룬다.
enum LoadState: Equatable {
    case idle
    case ok
    case rateLimited
    case failed
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var reading: UsageReading?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var loadState: LoadState = .idle
    /// 시작 시에는 연결 전으로 둔다. 첫 자동 조회가 창 없이 확인해 바로잡는다.
    @Published private(set) var connection: Connection = .notConnected

    /// 변경되면 타이머를 다시 잡아야 하므로 관찰 가능해야 한다.
    @Published var syncInterval: SyncInterval {
        didSet { defaults.set(syncInterval.rawValue, forKey: Self.syncIntervalKey) }
    }

    let strings: Strings
    let thresholds: Thresholds

    private let client: UsageProviding
    private let defaults: UserDefaults

    /// 연타와 429 이후 즉시 재시도를 막는다.
    private var gate = RequestGate()

    private static let syncIntervalKey = "syncIntervalSeconds"
    /// 사용자가 연결을 해제했는지. 해제했으면 "항상 허용" 상태여도 스스로 연결하지 않는다.
    private static let disconnectedKey = "disconnectedByUser"

    init(
        client: UsageProviding = UsageClient(tokenStore: TokenStore()),
        thresholds: Thresholds = .default,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.thresholds = thresholds
        self.defaults = defaults
        self.strings = Self.loadStrings()

        // 저장된 적이 없으면 0이 나온다. from(seconds:)이 기본값으로 되돌린다.
        self.syncInterval = SyncInterval.from(
            seconds: defaults.integer(forKey: Self.syncIntervalKey)
        )
    }

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

        do {
            reading = try await client.fetch(now: now, interactive: userInitiated)
            lastUpdated = now
            loadState = .ok
            gate.recordSuccess()
            connection = .connected
            defaults.removeObject(forKey: Self.disconnectedKey)
        } catch UsageClientError.credentials(.notFound) {
            connection = .notLoggedIn
        } catch UsageClientError.credentials(.denied) {
            connection = .accessDenied
        } catch UsageClientError.credentials(.needsConsent) {
            // 거부 안내는 사용자가 다시 시도할 때까지 유지한다. 자동 조회가 덮어쓰면
            // 방금 거부한 이유가 화면에서 사라진다.
            if connection != .accessDenied { connection = .notConnected }
        } catch UsageClientError.unauthorized {
            connection = .expired
        } catch UsageClientError.rateLimited(let retryAfter) {
            gate.recordRateLimited(at: now, retryAfter: retryAfter)
            loadState = .rateLimited
        } catch {
            loadState = .failed
        }
    }

    /// 이 앱이 더 이상 토큰을 읽지 않게 한다.
    ///
    /// macOS의 키체인 권한은 남는다. 안내는 `DisconnectAlert`가 맡는다.
    func disconnect() {
        client.forgetCredentials()
        reading = nil
        lastUpdated = nil
        loadState = .idle
        connection = .notConnected
        defaults.set(true, forKey: Self.disconnectedKey)
    }

    private var isDisconnectedByUser: Bool { defaults.bool(forKey: Self.disconnectedKey) }

    /// 상태 줄에 띄울 안내. 정상이면 표시하지 않는다.
    var notice: String? {
        switch loadState {
        case .idle, .ok: return nil
        case .rateLimited: return strings("status.rateLimited")
        case .failed: return strings("status.apiFailed")
        }
    }

    /// 값이 하나도 없을 때 화면 가운데에 띄울 설명.
    /// 제한에 걸린 상태를 "불러오는 중"으로 보여주면 사실과 다르다.
    func emptyStateMessage(at now: Date = Date()) -> String {
        switch loadState {
        case .rateLimited: return strings("status.rateLimited")
        case .failed: return strings("status.apiFailed")
        case .idle, .ok: return strings("status.loading")
        }
    }

    /// 대기 중이면 남은 시간을 문장으로. 아니면 nil.
    func retryMessage(at now: Date = Date()) -> String? {
        let remaining = cooldown(at: now)
        guard remaining > 0 else { return nil }
        return strings("status.retryIn", ["time": Self.durationText(remaining)])
    }

    private static func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let minutes = total / 60
        let remainder = total % 60
        return minutes > 0 ? "\(minutes)m \(remainder)s" : "\(remainder)s"
    }

    private static func loadStrings() -> Strings {
        guard
            let url = Paths.locale("ko"),
            let strings = try? Strings(contentsOf: url)
        else {
            // 문자열 파일을 못 찾으면 키가 그대로 보인다. 조용히 빈 화면이 되는 것보다 낫다.
            return Strings(table: [:])
        }
        return strings
    }
}
