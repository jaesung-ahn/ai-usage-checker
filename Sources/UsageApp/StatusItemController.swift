import AppKit
import Combine
import SwiftUI
import UsageCore

/// 메뉴바 아이템과 팝오버.
@MainActor
final class StatusItemController {
    private let state: AppState
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?

    /// 팝오버가 떠 있는 동안에만 설치되는 바깥 클릭 감시.
    private var outsideClickMonitor: Any?

    init(state: AppState) {
        self.state = state
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 이름을 주지 않으면 macOS가 Item-0 같은 공용 슬롯을 배정한다.
        // 그 슬롯의 숨김 상태는 이름 없는 모든 앱이 공유하므로, 다른 앱이 숨겨두면
        // 우리 항목까지 메뉴바에서 사라진다.
        statusItem.autosaveName = "ClaudeUsageMonitorStatusItem"

        // 메뉴바 항목이 유일한 진입점이다. 숨겨지면 종료할 방법조차 없다.
        statusItem.isVisible = true

        popover.behavior = .transient
        // 팝오버 재질이 밝은 배경을 비치면 다크 팔레트의 대비가 무너진다.
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(rootView: PopoverView(state: state))

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        // 값이 바뀌면 스스로 다시 그린다. 갱신 경로마다 render를 부르면 빠뜨리기 쉽다.
        // @Published는 willSet에서 방출되므로 메인 런루프로 한 번 넘겨 갱신 후의 값을 읽는다.
        cancellable = state.$reading
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.render() }

        render()
    }

    /// 5시간과 7일을 함께 표시한다. 하나만 보여주면 다른 쪽이 한도에 근접해도
    /// 안전해 보이는 상태가 만들어진다.
    func render() {
        guard let button = statusItem.button else {
            Log.ui.error("status item has no button")
            return
        }
        button.image = nil
        button.imagePosition = .noImage
        button.attributedTitle = MenuBarLabel.attributedTitle(
            items: menuBarItems(reading: state.reading, thresholds: state.thresholds),
            strings: state.strings,
            placeholder: state.strings("menubar.placeholder")
        )
    }

    @objc private func togglePopover() {
        popover.isShown ? close() : show()
    }

    /// `.transient`만으로는 다른 앱을 클릭했을 때 닫히지 않는다.
    /// 창을 갖지 않는 accessory 앱이라 바깥 클릭이 팝오버까지 전달되지 않기 때문이다.
    /// 전역 마우스 감시를 직접 설치한다. 마우스 이벤트 감시에는 별도 권한이 필요 없다.
    private func show() {
        guard let button = statusItem.button else { return }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func close() {
        popover.performClose(nil)

        // 감시를 남겨두면 팝오버가 닫힌 뒤에도 모든 클릭을 계속 받는다.
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
