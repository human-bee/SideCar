# SideCar

SideCar is a local-first macOS companion for Codex Desktop. It is designed as a floating native panel that observes active Codex threads, explains long-running work, and stages safe thread-level actions with explicit confirmation.

## Two-Hour MVP Status

This repository is a two-hour MVP scaffold, not a finished Codex automation product. It is ready for public review as a small Swift package that demonstrates the shape of a local-first SideCar app:

- Native AppKit + SwiftUI floating panel.
- SwiftPM modules for app contracts, Codex integration, fixture-backed thread storage, Realtime voice token brokering, and UI.
- Fixture/demo mode that runs without private Codex state.
- Safe action-gating contracts for queued messages, steer, fork, interrupt, review, compact, and approvals.
- Live Codex app-server snapshot loading through initialize, `thread/list`, and `thread/read`.
- App-server notification stream reader/reducer contracts for thread, turn, item, command-output, and approval-request events.
- Confirmed safe actions can be sent to the live Codex app-server for the MVP-supported methods.
- Approval cards are visible and scoped; app-server approval request ids and response payloads are modeled, but live approval fulfillment remains disabled until the same-connection response path is wired.
- Realtime readiness and screen-preview controls are available in Talk mode without sending visual context to a model.
- Documentation for architecture, privacy, compatibility, and design direction.

Current limitations are intentional: wiring the independent stream reader into app state, live approval response execution, signed/notarized distribution, full voice audio loop wiring, and production-grade ScreenCaptureKit UX are roadmap items.

## Roadmap

1. Wire the app-server stream reader into the app session lifecycle and live UI state.
2. Promote fixture snapshots into sanitized regression fixtures.
3. Add signed/notarized macOS packaging.
4. Expand visual context consent UX before enabling richer screen-aware features.
5. Harden global hotkeys beyond the current active-app scaffold.

## Requirements

- macOS 14 or newer.
- Xcode 16 or the Swift 6 toolchain.
- Optional: Codex Desktop for live integration work.
- Optional: `OPENAI_API_KEY` for Realtime voice experiments.

## Setup

Clone the repository, then run the Swift package checks:

```bash
swift test
swift build
make audit-share
```

Run fixture mode:

```bash
swift run SideCar
```

The app opens as a menu bar accessory with a floating SideCar panel. It tries live Codex app-server loading first and falls back to fixture mode if Codex is unavailable.

Build and open a local debug `.app` bundle:

```bash
make app
open -n dist/SideCar.app
```

The debug bundle is unsigned and intended for local review only. Release builds still need signing and notarization.

## OpenAI API Key

Fixture mode does not require an OpenAI key.

For local voice development, provide `OPENAI_API_KEY` through your shell or a local uncommitted `.env` file:

```bash
export OPENAI_API_KEY="sk-..."
swift run SideCar
```

Copy [.env.example](.env.example) only as a template. Do not commit real API keys. Normal app usage should store long-lived keys in Keychain and mint only ephemeral Realtime credentials for clients.

## Test And CI

```bash
swift test
```

GitHub Actions runs `swift test` on macOS for pushes and pull requests. See [.github/workflows/swift-test.yml](.github/workflows/swift-test.yml).

## Security Boundaries

MVP intentionally excludes direct shell execution, filesystem writes, config writes, plugin installation, worktree creation, and non-loopback app-server WebSocket access. Any future capability in those areas must be added through explicit action-gate contracts, tests, and documentation.

See [docs/architecture.md](docs/architecture.md), [docs/privacy.md](docs/privacy.md), [docs/security.md](docs/security.md), and [docs/compatibility.md](docs/compatibility.md).

## Contributing

Start with [docs/contributing.md](docs/contributing.md). Please include tests for contract changes and avoid committing private Codex rollouts, sqlite databases, screenshots, API keys, or `.env` files.
