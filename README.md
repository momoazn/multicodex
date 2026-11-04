# MultiCodex

[![CI](https://github.com/momoazn/multicodex/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/momoazn/multicodex/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/momoazn/multicodex)](https://github.com/momoazn/multicodex/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

A macOS menu bar app that manages multiple Codex CLI accounts. It shows usage for each account and switches accounts for you.

> MultiCodex is an independent open-source project. It is not affiliated with, endorsed by, or sponsored by OpenAI or the Codex CLI project.

[Download](https://github.com/momoazn/multicodex/releases/latest) | [Report a bug](https://github.com/momoazn/multicodex/issues) | [Development guide](docs/DEVELOPMENT.md)

## The problem

Codex limits usage per account in a 5-hour window and a weekly window. With more than one account, you must check each account by hand. You must also switch accounts by hand when one runs out.

MultiCodex does this work from the menu bar.

## Features

- **Usage view.** Shows 5-hour and weekly usage for each account. Data refreshes in the background.
- **Pace.** Compares the share of each window you have used with the share of time that has passed. It estimates when the quota runs out.
- **Fast switching.** Switch, re-login, or check auth status from the menu. No terminal commands.
- **Auto-switching.** Three strategies:

  | Strategy | When it switches |
  |----------|------------------|
  | Manual | Never. |
  | Failover | When the current account is near its limit or needs login. |
  | Expiry-Aware | To the account with the most unused quota that is about to reset. |

- **Notifications.** A native macOS notification appears on each auto-switch.
- **Sorting.** Sort accounts by used, remaining, or name, for the 5-hour or weekly window.
- **Backup and restore.** Export all accounts to one backup file, or one `auth.json` per account. Import with skip-existing or overwrite. Backups contain live credentials, so keep them private.
- **Settings window.** General, Accounts, System, Data, and About sections.

## Install

Requirements:

- macOS 13 (Ventura) or later
- [Codex CLI](https://github.com/openai/codex) in your `PATH`, or a custom path set in Settings > System

Steps:

1. Download the DMG from [Releases](https://github.com/momoazn/multicodex/releases/latest).
2. Drag **MultiCodex.app** to **Applications**.
3. Remove the quarantine flag once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/MultiCodex.app
   ```

   Why: the release build is ad-hoc signed, not signed with an Apple Developer ID, and not notarized. Gatekeeper blocks such apps on first launch. You own the copied app, so `sudo` is not needed. To check the code first, [build from source](#build-from-source).
4. Open MultiCodex. The menu bar icon appears.
5. Click the icon, then **Login New** to add an account. Repeat for each account.
6. Open Settings > General to choose an auto-switching strategy.

Shortcuts: `Cmd+R` refreshes usage. `Cmd+,` opens Settings.

## Architecture

MultiCodex is one SwiftUI executable with no third-party dependencies.

```
Sources/MultiCodex/
  App/              App entry point and delegate
  Core/             Pure logic: usage and pace models, account switching, reconciliation
  Infrastructure/   Codex runtime and RPC, usage API, auth and account storage, preferences, logging, notifications
  Features/         SwiftUI views and controllers (menu bar, settings, shared components)
```

Key points:

- **Usage source.** The app reads each account's usage from the ChatGPT usage endpoint with that account's saved login. If that fails, it falls back to the local `codex app-server` over JSON-RPC on stdio.
- **Account switching.** The Codex CLI reads one auth file, `~/.codex/auth.json`. MultiCodex keeps one auth file per account and swaps the active one in. It verifies account identity before it writes auth back, so one account's token cannot overwrite another's. See the [incident report](docs/INCIDENT-2026-05-05.md) for the bug that led to this check.
- **File safety.** Auth files and backups are written with mode `0600`.
- **Log redaction.** All app logs pass through a redactor. It removes emails, bearer tokens, and OAuth token values.
- **Concurrency.** `AccountsMenuViewModel` is `@MainActor`. Domain-scoped controllers handle refresh, login, settings, and account changes.

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for more detail.

## Tests

178 XCTest tests in 26 files. They cover account identity, reconciliation, auth swap, usage merge, pace, export, and error recovery.

```bash
just test    # run the tests
just check   # toolchain check, debug build, tests
```

CI builds and runs the tests on every pull request and every push to `main`. See [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Build from source

You need Xcode 15 or later and [just](https://github.com/casey/just).

```bash
git clone https://github.com/momoazn/multicodex.git
cd multicodex
just doctor   # check the toolchain
just run      # build and launch
```

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Run `just check` before you open a pull request. Report security issues privately, as [SECURITY.md](SECURITY.md) describes.

## License

MIT. See [LICENSE](LICENSE).

OpenAI and Codex are trademarks of their respective owners.
