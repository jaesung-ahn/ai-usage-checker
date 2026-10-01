import Combine
import SwiftUI
import UsageCore

/// 공급자 하나의 팝오버.
struct PopoverView: View {
    @ObservedObject var app: AppState
    @ObservedObject var state: ProviderState

    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// `now`가 1초마다 바뀌므로 대기가 끝나면 버튼이 저절로 다시 켜진다.
    private var canRefresh: Bool { _ = now; return state.canRefresh }

    private var icon: String {
        switch state.loadState {
        case .rateLimited: return "hourglass"
        case .failed: return "exclamationmark.triangle"
        case .idle, .ok: return "arrow.clockwise"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            header

            // 연결 문제는 이전 값보다 먼저 보여준다. 조치하지 않으면 값이 갱신되지 않는다.
            if let prompt = state.prompt {
                connectionCard(prompt)
            } else if let reading = state.reading {
                cards(for: reading)
            } else {
                emptyState
            }

            settings
            ProviderToggleList(app: app)
            footer
        }
        .padding(14)
        .frame(width: Theme.popoverWidth)
        .background(Theme.surface)
        .onReceive(tick) { now = $0 }
    }

    private var header: some View {
        HStack {
            Text(state.strings(state.provider.titleKey))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.title)

            Spacer()

            // 연결 문제가 있을 때는 카드의 버튼 하나로 조치를 모은다.
            if state.connection == .connected {
                Button {
                    Task { await state.refresh(userInitiated: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(canRefresh ? Theme.label : Theme.muted)
                }
                .buttonStyle(.plain)
                .disabled(!canRefresh)
                .help(state.strings("action.refresh"))
            }
        }
        .padding(.bottom, 2)
    }

    /// 값이 없는 창은 목록에 없으므로 행도 만들지 않는다. 0%로 표시하면 사용량이 없는 것처럼 보인다.
    private func cards(for reading: UsageReading) -> some View {
        ForEach(reading.windows) { window in
            card(window)
        }
    }

    private func card(_ window: UsageWindow) -> some View {
        WindowCard(
            title: windowTitle(window, strings: state.strings),
            window: window,
            level: app.thresholds.level(for: window.percent),
            now: now,
            strings: state.strings
        )
    }

    private func connectionCard(_ prompt: ConnectionPrompt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: connectionIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color(for: .warning))
                Text(state.strings(prompt.titleKey))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.title)
            }

            Text(state.strings(prompt.messageKey))
                .font(.system(size: 11))
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(state.strings(prompt.actionKey)) {
                    Task { await state.refresh(userInitiated: true) }
                }
                .controlSize(.small)
                .disabled(!canRefresh)

                if let retry = state.retryMessage(at: now) {
                    Text(retry)
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.top, 2)
        }
        .messageCard()
    }

    private var connectionIcon: String {
        switch state.connection {
        case .notConnected: return "link"
        case .notLoggedIn, .expired: return "person.crop.circle.badge.exclamationmark"
        case .accessDenied: return "lock"
        case .connected: return "checkmark"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.muted)
            Text(state.emptyStateMessage)
                .font(.system(size: 12))
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)
            if let retry = state.retryMessage(at: now) {
                Text(retry)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
            }
        }
        .messageCard()
    }

    private var settings: some View {
        HStack {
            Text(state.strings("settings.syncInterval"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.label)

            Spacer()

            Picker("", selection: $app.syncInterval) {
                ForEach(SyncInterval.allCases, id: \.self) { interval in
                    Text(state.strings(interval.labelKey)).tag(interval)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 84)
            .font(.system(size: 11))
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                if let updated = state.lastUpdated {
                    Text(state.strings("status.lastSync", ["time": Format.clock.string(from: updated)]))
                }
                if let notice = state.notice {
                    Text(notice).foregroundStyle(Theme.color(for: .warning))
                }
                if state.reading != nil, let retry = state.retryMessage(at: now) {
                    Text(retry).monospacedDigit()
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.muted)

            Spacer()

            if state.canDisconnect {
                Button(state.strings("action.disconnect")) {
                    state.disconnect()
                    // 해제는 이 앱만 멈춘다. 키체인 권한이 남아 있다는 사실을 숨기지 않는다.
                    DisconnectAlert.present(strings: state.strings)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
                .padding(.trailing, 6)
            }

            Button(state.strings("action.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(Theme.muted)
        }
        .padding(.top, 2)
    }
}

/// 공급자별 메뉴바 아이템 토글. 공급자 팝오버와 모두 꺼짐 팝오버가 함께 쓴다.
struct ProviderToggleList: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(app.strings("settings.providers"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.label)

            ForEach(Provider.allCases, id: \.self) { provider in
                Toggle(isOn: Binding(
                    get: { app.toggles.isEnabled(provider) },
                    set: { app.setEnabled(provider, $0) }
                )) {
                    Text(app.strings(provider.nameKey))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.title)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// 모든 공급자가 꺼졌을 때 앱 아이콘 아이템의 팝오버. 다시 켜거나 종료할 수 있어야 한다.
struct SettingsPopoverView: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            Text(app.strings("settings.allOff"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)
                .messageCard()

            ProviderToggleList(app: app)

            HStack {
                Spacer()
                Button(app.strings("action.quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: Theme.popoverWidth)
        .background(Theme.surface)
    }
}

private extension View {
    /// 연결 안내와 빈 상태처럼 값 대신 문장을 담는 카드.
    func messageCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.cardPadding)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

private struct WindowCard: View {
    let title: String
    let window: UsageWindow
    let level: UsageLevel
    let now: Date
    let strings: Strings

    private var accent: Color { Theme.color(for: level) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.label)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(window.percent))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.fill(for: level))
                Text("%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
            }

            UsageBar(percent: window.percent, level: level)

            if let countdown = countdown(resetsAt: window.resetsAt, now: now) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        countdown.isStale
                            ? strings("reset.soon")
                            : strings("reset.countdown", [
                                "time": formatCountdown(countdown)
                              ])
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.countdown)

                    if let resetsAt = window.resetsAt {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .semibold))
                            Text(Format.resetPoint.string(from: resetsAt))
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .fill(Theme.cardFill(for: level))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .strokeBorder(accent.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct UsageBar: View {
    let percent: Double
    let level: UsageLevel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(Theme.fill(for: level))
                    .frame(width: geometry.size.width * min(max(percent, 0), 100) / 100)
                    .shadow(color: Theme.color(for: level).opacity(0.5), radius: 4, y: 0)
            }
        }
        .frame(height: 8)
    }
}

private enum Format {
    static let clock = formatter("a h:mm")
    static let resetPoint = formatter("M/d(E) a h시")

    private static func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = template
        return formatter
    }
}
