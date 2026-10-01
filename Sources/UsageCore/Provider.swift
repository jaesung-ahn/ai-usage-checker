import Foundation

/// 사용량을 조회하는 AI 코딩 도구.
///
/// 공급자마다 정규화 함수가 따로 있고, 결과는 같은 `UsageReading`이다.
/// 선언 순서가 메뉴바 아이템과 설정 목록의 순서가 된다.
public enum Provider: String, CaseIterable, Sendable {
    case claude
    case codex

    /// 팝오버 제목.
    public var titleKey: String { "provider.\(rawValue).title" }
    /// 설정 토글 이름.
    public var nameKey: String { "provider.\(rawValue).name" }
    /// 메뉴바 라벨 앞에 붙는 약칭. 아이템이 여럿일 때 어느 공급자인지 구분한다.
    public var shortKey: String { "provider.\(rawValue).short" }
}

/// 메뉴바에 둘 아이템 하나.
public enum MenuBarEntry: Hashable, Sendable {
    case provider(Provider)
    /// 모든 공급자가 꺼졌을 때 남는 앱 아이콘. 누르면 설정이 열린다.
    case appIcon
}

/// 공급자별 켜고 끄기.
///
/// 토글 단위는 창이 아니라 공급자다. 창 하나만 켜두면 다른 창이 한도에 닿아도 안전해 보인다.
public struct ProviderToggles: Equatable, Sendable {
    /// 처음 실행하면 Claude만 켠다. Codex는 토글이 연결 동의이므로 사용자가 켜야 한다.
    public static let `default` = ProviderToggles(enabled: [.claude])

    public private(set) var enabled: Set<Provider>

    public init(enabled: Set<Provider>) {
        self.enabled = enabled
    }

    /// 저장된 값이 없으면 기본값이다. 알 수 없는 이름은 버린다.
    /// 앱 버전이 바뀌며 공급자가 줄어도 안전하게 동작해야 한다.
    public init(stored: [String]?) {
        guard let stored else {
            self = .default
            return
        }
        self.enabled = Set(stored.compactMap(Provider.init(rawValue:)))
    }

    /// 저장 형식. 순서를 고정해 같은 상태가 같은 값으로 저장되게 한다.
    public var stored: [String] {
        Provider.allCases.filter(enabled.contains).map(\.rawValue)
    }

    public func isEnabled(_ provider: Provider) -> Bool {
        enabled.contains(provider)
    }

    public mutating func set(_ provider: Provider, enabled isOn: Bool) {
        if isOn {
            enabled.insert(provider)
        } else {
            enabled.remove(provider)
        }
    }

    /// 켜진 공급자마다 아이템 하나. 모두 꺼지면 앱 아이콘 하나를 남긴다.
    ///
    /// 메뉴바 아이템이 앱의 유일한 진입점이다. 아무것도 남지 않으면 다시 켜거나 종료할 방법이 없다.
    public var menuBarEntries: [MenuBarEntry] {
        let providers = Provider.allCases.filter(enabled.contains)
        return providers.isEmpty ? [.appIcon] : providers.map(MenuBarEntry.provider)
    }
}
