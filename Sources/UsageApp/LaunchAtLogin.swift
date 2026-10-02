import Foundation
import ServiceManagement

/// 로그인 시 자동 실행.
///
/// 상태는 시스템이 가진다. 사용자가 시스템 설정에서 직접 바꿀 수 있어 앱에 따로 저장하지 않는다.
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    /// 마지막 등록이나 해제가 실패했는지. 설정 창이 안내 문구를 띄운다.
    @Published private(set) var failed = false

    private let service = SMAppService.mainApp

    init() {
        status = service.status
    }

    /// 승인 대기도 켠 것으로 본다. 사용자는 켰고, 남은 것은 시스템 설정의 허용이다.
    var isOn: Bool {
        status == .enabled || status == .requiresApproval
    }

    var requiresApproval: Bool {
        status == .requiresApproval
    }

    func set(_ on: Bool) {
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
            failed = false
        } catch {
            Log.ui.error("launch at login \(on ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            failed = true
        }
        status = service.status
    }

    /// 설정 창을 열 때 다시 읽는다. 그사이 시스템 설정에서 바뀌었을 수 있다.
    func refresh() {
        status = service.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
