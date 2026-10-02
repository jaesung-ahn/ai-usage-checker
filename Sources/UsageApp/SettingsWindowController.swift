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
        app.launchAtLogin.refresh()

        // 창이 없는 accessory 앱이라 앞으로 꺼내지 않으면 다른 앱 뒤에 깔린다.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(app: app, launchAtLogin: app.launchAtLogin)))
        window.title = app.strings("settings.title")
        window.styleMask = [.titled, .closable]
        // 닫아도 다시 열 수 있게 붙잡아 둔다. 기본값이면 닫을 때 해제되어 다음 열기에서 죽는다.
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

/// 공급자 토글, 갱신 주기, 로그인 시 자동 실행, 종료.
///
/// 시스템 외형을 따른다. 팝오버처럼 반투명 재질 위에 있지 않아 고정 다크 팔레트가 필요 없다.
struct SettingsView: View {
    @ObservedObject var app: AppState
    // AppState 안의 객체라도 따로 관찰해야 바뀔 때 다시 그린다.
    @ObservedObject var launchAtLogin: LaunchAtLogin

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

            Section {
                Toggle(app.strings("settings.launchAtLogin"), isOn: Binding(
                    get: { launchAtLogin.isOn },
                    set: { launchAtLogin.set($0) }
                ))
                if launchAtLogin.failed {
                    Text(app.strings("settings.launchAtLogin.failed"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if launchAtLogin.requiresApproval {
                    // 켰어도 사용자가 허용하기 전에는 실행되지 않는다. 켜진 토글만 보면 모른다.
                    HStack {
                        Text(app.strings("settings.launchAtLogin.requiresApproval"))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(app.strings("action.openLoginItems")) {
                            launchAtLogin.openSystemSettings()
                        }
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
