import AppKit
import Combine
import UsageCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var menuBar: MenuBarController!
    private var timer: Timer?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = AppState()
        menuBar = MenuBarController(app: state)

        refresh()
        schedule(state.syncInterval)

        // 주기가 바뀌면 타이머를 다시 잡는다.
        cancellable = state.$syncInterval
            .removeDuplicates()
            .sink { [weak self] interval in
                Task { @MainActor in self?.schedule(interval) }
            }
    }

    private func schedule(_ interval: SyncInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: interval.seconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func refresh() {
        state.refreshEnabled()
    }
}
