# Claude Usage Monitor

A macOS menu bar app that shows your Claude Code usage limits at a glance.

```
5h 15% · 7d 21%
```

Both limits apply independently — hitting either one blocks you, so both are always visible.
Click the menu bar item for details: per-model weekly pools, reset countdowns, and the sync interval.

## Requirements

- macOS 13 or later
- Xcode 15 or later (SwiftPM's default build system requires it)
- Claude Code, already logged in

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

There is nothing to configure. The app reuses the OAuth token that Claude Code already stores,
reading `~/.claude/.credentials.json` first and falling back to the macOS Keychain.
macOS asks for permission on first Keychain access.

The token stays in memory. It is never logged, written to disk, or sent anywhere except
`api.anthropic.com`.

## How it works

Usage comes from `GET https://api.anthropic.com/api/oauth/usage`, the same endpoint that backs
Claude Code's `/usage` command. It is a read-only endpoint: requests cost no tokens and do not
count toward your usage.

It is rate limited, though, and the limit is undocumented and tight. The app defends against this:

- Manual refresh is throttled, and the button is disabled while a cooldown is active
- On HTTP 429 it backs off exponentially, honoring `Retry-After` when the server sends it
- A successful request clears the backoff

The sync interval is configurable from the popover (1 minute to 1 hour, 5 minutes by default).

## Development

```bash
swift test      # 38 tests
swift build
```

The package has two targets:

- `UsageCore` — pure logic. No AppKit, SwiftUI, URLSession or Keychain. This is where response
  normalization, thresholds, countdowns and request gating live, and it is the only target under test
- `UsageApp` — the menu bar app. AppKit and SwiftUI are confined here

Tests read real API responses from `Tests/Fixtures/`. To refresh them after an API change,
run `scripts/capture-usage-response.sh`, strip anything you do not need, and replace the fixture.

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

Not affiliated with Anthropic.
