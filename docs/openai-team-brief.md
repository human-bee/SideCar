# SideCar OpenAI Team Brief

## What This Is

SideCar is a local-first macOS companion for Codex Desktop. It explores a second-hand operator surface for long-running Codex sessions: observe the active thread, ask tangent questions, stage safe actions, and eventually speak to a Realtime agent without disturbing the running Codex turn.

## Current MVP

- Native AppKit + SwiftUI floating panel.
- Codex-inspired light/dark visual system.
- Fixture mode for safe demos without private Codex state.
- Live Codex app-server snapshot loading with `initialize`, `thread/list`, and `thread/read`.
- Safe action staging and confirmation for supported thread-level app-server methods.
- Realtime `gpt-realtime-1.5` session broker seams using Keychain or local dev `OPENAI_API_KEY`.
- Screen-capture consent model without automatic model send.
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

- Continuous `item/*`, `turn/*`, and approval request event streaming is not finished.
- Realtime audio loop is not fully wired; session minting is proven.
- Active frontmost Codex thread bridge through Codex++ is optional and not fully integrated.
- Global hotkey is currently active-app scaffolding, not a hardened system-wide shortcut.
- Notarized app packaging is not done.

## Suggested Demo Path

1. Run `swift test`.
2. Run `swift run SideCar`.
3. Show fixture fallback and source diagnostics.
4. Open a live Codex Desktop session and refresh SideCar to load recent threads.
5. Stage a queued message and show target-card confirmation.
6. Show Settings key entry and explain Realtime session minting.
7. Review `docs/security.md` and `docs/compatibility.md`.

## Near-Term Finish Line

The next meaningful technical milestone is event streaming plus approval UI. That turns SideCar from a live snapshot/control prototype into the intended long-running companion.
