# Claude Usage Monitor

A macOS menu bar app that shows your Claude Code and Codex usage limits at a glance.

```
C 5h 15% · 7d 21%    Cx 5h 2% · 7d 0%
```

Each provider gets its own menu bar item. The 5-hour and 7-day limits apply independently —
hitting either one blocks you, so both are always visible.
Click an item for details: per-model weekly pools or additional limits, reset countdowns, and the sync interval.

Turn providers on and off under "메뉴바 항목" in the popover. Only Claude is on by default.
If you turn every provider off, a single app icon remains so you can turn one back on or quit.

## Requirements

- macOS 13 or later
- Xcode (the full app, not just the Command Line Tools). Tested with Xcode 27.0.
  With only the Command Line Tools installed, `swift build` fails. After installing Xcode,
  open it once to finish setup, and if `xcode-select -p` still points to `CommandLineTools`, run
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- Claude Code, already logged in
- For Codex: the Codex CLI, logged in with a ChatGPT account (`codex login`). API key login is not supported

## Install

```bash
git clone https://github.com/jaesung-ahn/claude-usage-monitor.git
cd claude-usage-monitor
./build.sh --install
```

This builds the app, moves it to `/Applications`, and launches it.
Omit `--install` to build into `./build.noindex` without installing.

No prebuilt release is available yet, so you have to build from source.

## Authentication

The app never asks you to log in. It reuses the tokens each tool already stores.

### Claude

The app reuses the OAuth token that Claude Code already stores. It reads
`~/.claude/.credentials.json` first and falls back to the macOS Keychain.

- **Connect.** On first launch the popover shows a Connect button. The app does not touch the
  Keychain until you press it. macOS then asks for permission. Choose "Always Allow" to connect
  automatically on later launches; "Allow" lasts until the app quits
- **Automatic reads never prompt.** Launch and periodic refreshes read the Keychain with user
  interaction disabled. If permission is needed, the app shows the Connect button instead of a
  system dialog
- **Disconnect.** Disconnect in the popover stops the app from reading the token, including on
  later launches. The Keychain permission itself stays. To remove it, open Keychain Access, find
  `Claude Code-credentials`, and remove ClaudeUsageMonitor from its Access Control list

The token stays in memory. It is never logged, written to disk, or sent anywhere except
`api.anthropic.com`.

Anthropic's [terms for Claude Code](https://code.claude.com/docs/en/legal-and-compliance)
restrict using subscription OAuth tokens outside Claude Code. This app only reads usage, but it
is not endorsed by Anthropic, and you should review those terms before using it.

### Codex

The app reads the ChatGPT token that the Codex CLI stores in `~/.codex/auth.json`. There is no
Keychain prompt, and the app never writes to that file.

- **Turning Codex on is the consent.** The app does not read the file until you turn Codex on
- **Expired token.** The app does not refresh tokens. Run `codex` once to refresh it, then press Recheck
- **Turning Codex off** stops the app from reading the file

The token is read on each request and not kept in memory. It is never logged, written to disk,
or sent anywhere except `chatgpt.com`. Account identifiers in the response are ignored.
Codex configured to store credentials in the OS keychain is not supported.

OpenAI's [guidance for third-party integrations](https://developers.openai.com/siwc/token-sharing-open-source/codex-app-server)
asks apps to go through `codex app-server` rather than reading `auth.json` or calling internal
APIs. This app calls the usage endpoint directly. It is not endorsed by OpenAI, and you should
review that guidance before using it.

## How it works

| Provider | Endpoint | Backs |
|---|---|---|
| Claude | `GET https://api.anthropic.com/api/oauth/usage` | Claude Code's `/usage` |
| Codex | `GET https://chatgpt.com/backend-api/wham/usage` | Codex CLI's `/usage` |

Both are read-only. Claude's endpoint costs no tokens and does not count toward your usage.
Whether Codex's does has not been verified. Neither endpoint is documented, so their shape can
change without notice.

Both are rate limited, and Claude's limit is undocumented and tight. The app defends against this,
separately for each provider, so a 429 from one does not block the other:

- Manual refresh is throttled, and the button is disabled while a cooldown is active
- On HTTP 429 it backs off exponentially, honoring `Retry-After` when the server sends it
- A successful request clears the backoff

The sync interval is configurable from the popover (1 minute to 1 hour, 5 minutes by default) and shared by all providers.

## Development

```bash
swift test      # 85 tests
swift build
```

The package has two targets:

- `UsageCore` — pure logic. No AppKit, SwiftUI, URLSession or Keychain. This is where response
  normalization, thresholds, countdowns, request gating and connection state transitions live, and it is the only target under test
- `UsageApp` — the menu bar app. AppKit and SwiftUI are confined here

Tests read real API responses from `Tests/Fixtures/`. To refresh them after an API change,
run `scripts/capture-usage-response.sh` (Claude) or `scripts/capture-codex-usage-response.sh` (Codex),
strip anything you do not need — including account identifiers — and replace the fixture.

Display strings live in `locales/ko.json` rather than in code. Adding a language means adding a file.

## Status

Working, but not yet packaged for distribution. Known gaps:

- Apple Silicon only, no universal binary
- Ad-hoc signed, so it will not run on another machine without building it there
- No launch-at-login toggle, no auto-update
- Korean only

Burn rate, reset-time projections, daily token trends and notifications are planned but not built.

## License

MIT. See [LICENSE](LICENSE).

Not affiliated with Anthropic or OpenAI.
