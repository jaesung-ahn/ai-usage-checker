import AppKit
import Combine
import SwiftUI
import UsageCore

/// 공급자 토글에 맞춰 메뉴바 아이템을 두고 거둔다.
///
/// 켜진 공급자마다 독립된 아이템 하나. 모두 꺼지면 앱 아이콘 아이템 하나만 남긴다.
@MainActor
final class MenuBarController {
    private let app: AppState
    private let settings: SettingsWindowController
    private var items: [MenuBarEntry: StatusItemController] = [:]
    private var cancellable: AnyCancellable?

    init(app: AppState) {
        self.app = app
        self.settings = SettingsWindowController(app: app)
        sync(app.toggles.menuBarEntries)

        cancellable = app.$toggles
            .map(\.menuBarEntries)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] entries in self?.sync(entries) }
    }

    private func sync(_ entries: [MenuBarEntry]) {
        for (entry, item) in items where !entries.contains(entry) {
            item.remove()
            items[entry] = nil
        }
        for entry in entries where items[entry] == nil {
            items[entry] = makeItem(for: entry)
        }
    }

    /// 떠 있는 팝오버를 닫고 설정 창을 연다. 팝오버가 창을 가리지 않게 한다.
    private func openSettings() {
        items.values.forEach { $0.closePopover() }
        settings.show()
    }

    private func makeItem(for entry: MenuBarEntry) -> StatusItemController {
        switch entry {
        case .provider(let provider):
            return providerItem(app.state(for: provider))
        case .appIcon:
            return appIconItem()
        }
    }

    /// 5시간과 7일을 함께 표시한다. 하나만 보여주면 다른 쪽이 한도에 근접해도
    /// 안전해 보이는 상태가 만들어진다.
    private func providerItem(_ state: ProviderState) -> StatusItemController {
        let app = app
        return StatusItemController(
            autosaveName: Self.autosaveName(for: .provider(state.provider)),
            click: .popover(AnyView(PopoverView(
                app: app,
                state: state,
                openSettings: { [weak self] in self?.openSettings() }
            ))),
            redraw: state.$reading.map { _ in () }
                .merge(with: state.$connection.map { _ in () })
                .eraseToAnyPublisher(),
            render: { button in
                button.image = nil
                button.imagePosition = .noImage
                button.attributedTitle = MenuBarLabel.attributedTitle(
                    prefix: app.strings(state.provider.shortKey),
                    // 연결 문제가 있으면 값을 갱신할 수 없다. 멈춘 값을 현재 값처럼 보여주지 않는다.
                    items: menuBarItems(
                        reading: state.connection == .connected ? state.reading : nil,
                        thresholds: app.thresholds
                    ),
                    strings: app.strings,
                    placeholder: app.strings("menubar.placeholder"),
                    needsAttention: state.prompt != nil
                )
            }
        )
    }

    /// 모두 꺼졌을 때 남는 진입점. 팝오버 없이 설정 창을 연다.
    private func appIconItem() -> StatusItemController {
        let app = app
        return StatusItemController(
            autosaveName: Self.autosaveName(for: .appIcon),
            click: .action { [weak self] in self?.openSettings() },
            redraw: Empty().eraseToAnyPublisher(),
            render: { button in
                let image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: nil)
                // 템플릿이어야 메뉴바의 밝고 어두운 외형을 따른다.
                image?.isTemplate = true
                button.image = image
                button.imagePosition = image == nil ? .noImage : .imageOnly
                // 기호를 못 찾으면 빈 아이템이 된다. 누를 곳이 보이지 않으면 진입점이 사라진다.
                if image == nil { button.title = app.strings("menubar.placeholder") }
            }
        )
    }

    /// 바꾸면 사용자가 옮겨둔 위치가 풀린다. 번들 ID를 바꿀 때 함께 정했다.
    private static func autosaveName(for entry: MenuBarEntry) -> String {
        let base = "AIUsageCheckerStatusItem"
        switch entry {
        case .provider(let provider): return "\(base).\(provider.rawValue)"
        case .appIcon: return "\(base).appIcon"
        }
    }
}
