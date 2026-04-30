# SideCar Architecture

SideCar is a native macOS companion app for Codex Desktop. The architecture is intentionally local-first and adapter-driven so Codex version drift stays contained.

## Layers

- `SideCarApp`: AppKit process shell, menu bar item, floating panel.
- `UIComponents`: SwiftUI surface for status, timeline map, thread switchboard, talk dock, and confirmation cards.
- `AppCore`: SideCar-owned contracts and action gates.
- `CodexAdapter`: Codex app-server JSON-RPC client, optional Codex++ active-thread bridge, read-only sqlite/rollout fallbacks.
- `ThreadStore`: fixture, cache, and search layer.
- `VoiceCore`: Realtime token broker, voice tool policy, and screen-context consent helpers.

## Source Of Truth

Live mode should use Codex app-server as the authoritative source for thread status, turn lifecycle, item events, and safe thread controls.

Active-thread resolution order:

1. Optional Codex++ bridge reports the frontmost Codex thread.
2. Codex app-server reports loaded/running threads.
3. Manual SideCar selection from app-server thread list.
4. Read-only fallback from local sqlite and rollout files.

Fallbacks can show history and stale status. They cannot execute actions.

## Action Gating

MVP actions are limited to safe thread-level controls:

- queue message
- steer active turn
- fork thread
- interrupt turn
- start review
- compact thread
- approval decision

Every mutation is staged as a `SideCarAction` and must pass `ActionGate` before execution. The target card must show thread id, turn id when relevant, action kind, and payload preview.

Explicitly excluded from MVP:

- `thread/shellCommand`
- `command/exec`
- filesystem writes
- config writes
- plugin installation
- worktree creation
- non-loopback app-server WebSocket

## Realtime Voice

Voice is speech-to-action by default. The app mints ephemeral Realtime sessions through a native broker using a BYO OpenAI key from Keychain. Voice tools may inspect and draft freely, but all mutations stage an action card and require confirmation.

## Screen Awareness

Full-desktop capture is permissioned and on-demand/event-driven. Before visual context is sent to a model, the user must preview and accept the capture for that session.
