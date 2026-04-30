# SideCar OpenAI Team Brief

## What This Is

SideCar is a local-first macOS companion for Codex Desktop. It explores a second-hand operator surface for long-running Codex sessions: observe the active thread, ask tangent questions, stage safe actions, and eventually speak to a Realtime agent without disturbing the running Codex turn.

## Current MVP

- Native AppKit + SwiftUI floating panel.
- Codex-inspired light/dark visual system.
- Fixture mode for safe demos without private Codex state.
- Live Codex app-server snapshot loading with `initialize`, `thread/list`, and `thread/read`.
- App-server event stream reader/reducer and approval request/response contracts with fixture tests.
- Safe action staging and confirmation for supported thread-level app-server methods.
- `/side` is modeled as a first-class guarded tangent primitive; the current adapter maps it to a non-persistent `thread/fork` until a dedicated app-server method is available.
- Realtime `gpt-realtime-1.5` session broker seams using Keychain or local dev `OPENAI_API_KEY`.
- Realtime readiness check, Option-Shift-Space Talk hotkey, plus screen-capture preview consent controls without automatic model send.
- Quieter single-column SideCar UI inspired by the design exploration.
- Swift test suite and GitHub Actions.

## Why It Matters

Codex is strongest when it can run for a while. The missing surface is a lightweight companion that answers:

- What is Codex doing right now?
- Is it blocked on approval, user input, or a failed command?
- What changed since I stepped away?
- Should I queue a follow-up, steer the active turn, fork the thread, or leave it alone?
- Can a realtime voice assistant inspect the run and stage actions without becoming a second uncontrolled operator?

## Current Safety Boundary

SideCar deliberately excludes direct shell execution, arbitrary filesystem writes, config mutation, plugin installation, worktree creation, and non-loopback app-server WebSocket access. Mutations are staged as explicit `SideCarAction` values and require confirmation.

## Known Gaps

- Continuous `item/*`, `turn/*`, and approval request event parsing/reducing is modeled, but not yet wired into a persistent live app session.
- Realtime audio loop is not fully wired; session minting/readiness is proven.
- Approval request/response contracts are modeled, but live accept/decline is not wired to the same active app-server connection.
- Active frontmost Codex thread bridge through Codex++ is optional and not fully integrated.
- Global hotkeys use AppKit event monitors and may still need macOS Input Monitoring hardening for fully reliable system-wide capture.
- Notarized app packaging is not done.

## Suggested Demo Path

1. Run `swift test`.
2. Run `make app && open -n dist/SideCar.app`.
3. Show fixture fallback and source diagnostics.
4. Open a live Codex Desktop session and refresh SideCar to load recent threads.
5. Stage a `/side` tangent and a queued message; show target-card confirmation.
6. Press Option-Shift-Space to open Talk mode, then show Settings key entry, Realtime check, and screen preview consent.
7. Review `docs/security.md` and `docs/compatibility.md`.

## Near-Term Finish Line

The next meaningful technical milestone is one persistent app-server session that keeps the stream reader alive, updates UI state in realtime, and writes approval responses back on the same connection.
