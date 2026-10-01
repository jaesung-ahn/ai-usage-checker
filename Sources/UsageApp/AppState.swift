import Foundation
import UsageCore

/// 공급자가 공유하는 설정과 공급자별 상태.
@MainActor
final class AppState: ObservableObject {
    /// 변경되면 타이머를 다시 잡아야 하므로 관찰 가능해야 한다. 공급자가 공유한다.
    @Published var syncInterval: SyncInterval {
        didSet { defaults.set(syncInterval.rawValue, forKey: Self.syncIntervalKey) }
    }

    /// 바뀌면 메뉴바 아이템을 다시 맞춘다.
    @Published private(set) var toggles: ProviderToggles

    let strings: Strings
    let thresholds: Thresholds

    private let providers: [Provider: ProviderState]
    private let defaults: UserDefaults

    private static let syncIntervalKey = "syncIntervalSeconds"
    private static let enabledProvidersKey = "enabledProviders"

    init(thresholds: Thresholds = .default, defaults: UserDefaults = .standard) {
        let strings = Self.loadStrings()
        self.strings = strings
        self.thresholds = thresholds
        self.defaults = defaults

        // 저장된 적이 없으면 0이 나온다. from(seconds:)이 기본값으로 되돌린다.
        self.syncInterval = SyncInterval.from(
            seconds: defaults.integer(forKey: Self.syncIntervalKey)
        )
        self.toggles = ProviderToggles(stored: defaults.stringArray(forKey: Self.enabledProvidersKey))

        var providers: [Provider: ProviderState] = [:]
        for provider in Provider.allCases {
            providers[provider] = ProviderState(
                provider: provider,
                client: Self.client(for: provider),
                strings: strings,
                defaults: defaults
            )
        }
        self.providers = providers
    }

    func state(for provider: Provider) -> ProviderState {
        // 모든 공급자의 상태를 init에서 만든다.
        providers[provider]!
    }

    /// 켜진 공급자만 조회한다. 꺼진 공급자는 자격증명을 읽지 않는다.
    func refreshEnabled() {
        for provider in toggles.enabled {
            let state = state(for: provider)
            Task { await state.refresh() }
        }
    }

    /// Codex는 토글을 켜는 것이 연결 동의다. 켜는 즉시 조회한다.
    ///
    /// Claude는 켜도 키체인 창을 띄우지 않는다. 연결은 팝오버의 연결 버튼이 맡는다.
    func setEnabled(_ provider: Provider, _ isOn: Bool) {
        guard toggles.isEnabled(provider) != isOn else { return }
        toggles.set(provider, enabled: isOn)
        defaults.set(toggles.stored, forKey: Self.enabledProvidersKey)

        let state = state(for: provider)
        if isOn {
            Task { await state.refresh() }
        } else {
            state.stop()
        }
    }

    private static func client(for provider: Provider) -> UsageProviding {
        switch provider {
        case .claude: return ClaudeClient()
        case .codex: return CodexClient()
        }
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
