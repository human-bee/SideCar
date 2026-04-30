# SideCar Architecture

SideCar is a native macOS companion app for Codex Desktop. The architecture is intentionally local-first and adapter-driven so Codex version drift stays contained.

## Layers

- `SideCarApp`: AppKit process shell, menu bar item, floating panel.
- `UIComponents`: SwiftUI surface for status, timeline map, thread switchboard, talk dock, and confirmation cards.
- `AppCore`: SideCar-owned contracts and action gates.
- `CodexAdapter`: Codex app-server JSON-RPC client, notification parser/pump, stream reader/reducer contracts, approval request/response contracts, optional Codex++ active-thread bridge, read-only sqlite/rollout fallbacks.
- `ThreadStore`: fixture, cache, and search layer.
- `VoiceCore`: Realtime token broker, voice tool policy, and screen-context consent helpers.

## Source Of Truth

Live mode should use Codex app-server as the authoritative source for thread status, turn lifecycle, item events, and safe thread controls.

Current MVP live loading is intentionally bounded: startup uses recent `thread/list` snapshots to avoid blocking launch on very large thread reads. `CodexAdapter` has tested notification reader and reducer contracts for app-server event frames; wiring that reader into a dedicated long-lived app session is the next integration step.

Active-thread resolution order:

1. Optional Codex++ bridge reports the frontmost Codex thread.
2. Codex app-server reports loaded/running threads.
3. Manual SideCar selection from app-server thread list.
4. Read-only fallback from local sqlite and rollout files.

Fallbacks can show history and stale status. They cannot execute actions.

## Action Gating

MVP actions are limited to safe thread-level controls:

- queue message
- `/side` tangent question
- steer active turn
- fork thread
- interrupt turn
- start review
- compact thread
- approval decision staging

Every mutation is staged as a `SideCarAction` and must pass `ActionGate` before execution. The target card must show thread id, turn id when relevant, action kind, and payload preview.

The `/side` primitive is modeled as `SideCarActionKind.sideQuestion`. Until Codex app-server exposes a dedicated side-conversation method, the live adapter maps it to `thread/fork` with `persistExtendedHistory: false` and developer instructions that treat the parent thread as read-only reference context. This keeps `/side` distinct from both queue and steer in SideCar's product model while preserving a safe fallback transport.

Approval cards are currently inspection/staging only. Codex app-server approvals are server-initiated JSON-RPC requests. SideCar now models command/file approval requests, preserves the server request id on normalized approval timeline items, and encodes approval JSON-RPC responses. Live accept/decline remains disabled until those responses are written on the same active app-server connection. SideCar intentionally does not fake approvals as normal client method calls.

Explicitly excluded from MVP:

- `thread/shellCommand`
- `command/exec`
- filesystem writes
- config writes
- plugin installation
- worktree creation
- non-loopback app-server WebSocket

## Realtime Voice

Voice is speech-to-action by default. The app mints ephemeral Realtime sessions through a native broker using a BYO OpenAI key from Keychain. Talk mode can check Realtime readiness and show redacted session diagnostics. Option-Shift-Space opens Talk mode and runs that readiness check. Voice tools may inspect and draft freely, but all mutations stage an action card and require confirmation. Full live audio streaming remains future work.

## Screen Awareness

Full-desktop capture is permissioned and on-demand/event-driven. Talk mode can capture preview metadata, accept a preview, and clear it. Before visual context is sent to a model, the user must preview and accept the capture for that session; this build does not automatically send captured images.
