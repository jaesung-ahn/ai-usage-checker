import AppKit
import UsageCore

/// 연결 해제 뒤 키체인 권한을 어떻게 지우는지 알린다.
///
/// 앱이 권한을 직접 지우지 않는다. 권한은 Claude Code가 만든 항목에 붙어 있어,
/// 잘못 다시 쓰면 Claude Code 로그인이 깨질 수 있다. 키체인 접근 앱을 여는 데서 멈춘다.
@MainActor
enum DisconnectAlert {
    private static let keychainAccess = "com.apple.keychainaccess"

    static func present(strings: Strings) {
        let alert = NSAlert()
        alert.messageText = strings("disconnect.title")
        alert.informativeText = strings("disconnect.message")
        alert.addButton(withTitle: strings("action.openKeychainAccess"))
        alert.addButton(withTitle: strings("action.close"))

        // 창이 없는 앱이라 앞으로 꺼내지 않으면 경고창이 다른 앱 뒤에 깔린다.
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: keychainAccess) else {
            Log.ui.error("keychain access app not found")
            return
        }

        // 앱만 열면, 이미 창 없이 떠 있을 때 앞으로 가져오기만 하고 창이 나타나지 않는다.
        // 항목이 있는 로그인 키체인을 문서로 넘기면 실행 여부와 상관없이 창이 열린다.
        let loginKeychain = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Keychains/login.keychain-db")
        NSWorkspace.shared.open(
            [loginKeychain],
            withApplicationAt: app,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
