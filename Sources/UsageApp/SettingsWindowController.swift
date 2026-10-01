import AppKit
import SwiftUI
import UsageCore

/// 설정 창. 모달이 아니며 하나만 만들어 다시 연다.
///
/// 설정을 바꾸는 동안에도 메뉴바 값을 볼 수 있어야 하므로 모달로 띄우지 않는다.
@MainActor
final class SettingsWindowController {
    private let app: AppState
    private var window: NSWindow?

    init(app: AppState) {
        self.app = app
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window

        // 창이 없는 accessory 앱이라 앞으로 꺼내지 않으면 다른 앱 뒤에 깔린다.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(app: app)))
        window.title = app.strings("settings.title")
        window.styleMask = [.titled, .closable]
        // 닫아도 다시 열 수 있게 붙잡아 둔다. 기본값이면 닫을 때 해제되어 다음 열기에서 죽는다.
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

/// 공급자 토글, 갱신 주기, 종료.
///
/// 시스템 외형을 따른다. 팝오버처럼 반투명 재질 위에 있지 않아 고정 다크 팔레트가 필요 없다.
struct SettingsView: View {
    @ObservedObject var app: AppState

    var body: some View {
        Form {
            // 모두 꺼진 상태에서는 앱 아이콘만 남는다. 왜 사용량이 안 보이는지 알려준다.
            if app.toggles.enabled.isEmpty {
                Section {
                    Text(app.strings("settings.allOff"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(app.strings("settings.providers")) {
                ForEach(Provider.allCases, id: \.self) { provider in
                    Toggle(app.strings(provider.nameKey), isOn: Binding(
                        get: { app.toggles.isEnabled(provider) },
                        set: { app.setEnabled(provider, $0) }
                    ))
                }
            }

            Section {
                Picker(app.strings("settings.syncInterval"), selection: $app.syncInterval) {
                    ForEach(SyncInterval.allCases, id: \.self) { interval in
                        Text(app.strings(interval.labelKey)).tag(interval)
                    }
                }
            }

            // 모두 꺼졌을 때는 이 창이 유일한 진입점이다. 종료할 수 있어야 한다.
            HStack {
                Spacer()
                Button(app.strings("action.quit")) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 340)
        .fixedSize()
    }
}
