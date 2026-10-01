import AppKit
import Combine
import SwiftUI
import UsageCore

/// 메뉴바 아이템 하나와 그 팝오버.
@MainActor
final class StatusItemController {
    /// 아이템을 눌렀을 때 할 일.
    enum Click {
        case popover(AnyView)
        case action(() -> Void)
    }

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let onClick: (() -> Void)?
    private var cancellable: AnyCancellable?

    /// 팝오버가 떠 있는 동안에만 설치되는 바깥 클릭 감시.
    private var outsideClickMonitor: Any?

    /// - Parameters:
    ///   - autosaveName: 아이템마다 고유해야 한다.
    ///   - redraw: 값이 바뀔 때마다 방출한다. 그때만 라벨을 다시 그린다.
    ///   - render: 라벨을 그린다.
    init(
        autosaveName: String,
        click: Click,
        redraw: AnyPublisher<Void, Never>,
        render: @escaping (NSStatusBarButton) -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 이름을 주지 않으면 macOS가 Item-0 같은 공용 슬롯을 배정한다.
        // 그 슬롯의 숨김 상태는 이름 없는 모든 앱이 공유하므로, 다른 앱이 숨겨두면
        // 우리 항목까지 메뉴바에서 사라진다. 아이템끼리도 이름이 겹치면 같은 문제가 생긴다.
        statusItem.autosaveName = autosaveName

        // 메뉴바 항목이 유일한 진입점이다. 숨겨지면 종료할 방법조차 없다.
        statusItem.isVisible = true

        switch click {
        case .popover(let content):
            onClick = nil
            popover.behavior = .transient
            // 팝오버 재질이 밝은 배경을 비치면 다크 팔레트의 대비가 무너진다.
            popover.appearance = NSAppearance(named: .darkAqua)
            popover.contentViewController = NSHostingController(rootView: content)
        case .action(let action):
            onClick = action
        }

        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)

        // 값이 바뀌면 스스로 다시 그린다. 갱신 경로마다 render를 부르면 빠뜨리기 쉽다.
        // @Published는 willSet에서 방출되므로 메인 런루프로 한 번 넘겨 갱신 후의 값을 읽는다.
        let button = statusItem.button
        cancellable = redraw
            .receive(on: RunLoop.main)
            .sink { _ in
                guard let button else { return }
                render(button)
            }

        if let button {
            render(button)
        } else {
            Log.ui.error("status item has no button")
        }
    }

    /// 메뉴바에서 내린다. 떠 있는 팝오버와 바깥 클릭 감시도 함께 거둔다.
    func remove() {
        closePopover()
        cancellable = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func clicked() {
        if let onClick {
            onClick()
        } else {
            popover.isShown ? closePopover() : show()
        }
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
            Task { @MainActor in self?.closePopover() }
        }
    }

    func closePopover() {
        popover.performClose(nil)

        // 감시를 남겨두면 팝오버가 닫힌 뒤에도 모든 클릭을 계속 받는다.
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
