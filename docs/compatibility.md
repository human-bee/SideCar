# Compatibility

## macOS

SideCar targets macOS 14.2 or newer.

## Codex

Codex app-server is treated as version-sensitive. Startup should probe:

- bundled Codex binary path
- app-server proxy launch
- supported methods
- event/item payload compatibility

Unsupported capabilities must degrade visibly.

## Current MVP Status

The scaffold defaults to fixture mode, and `CodexAdapter` includes a guarded app-server control surface for the live MVP actions:

- queue/start a message with `turn/start`
- stage a `/side` tangent as a guarded, non-persistent `thread/fork`
- steer the active turn with `turn/steer`
- interrupt a running turn with `turn/interrupt`
- fork a thread with `thread/fork`
- compact a thread with `thread/compact/start`
- start a review with `review/start`

These requests are built through typed helpers before JSON-RPC transport execution.

## Unsupported In MVP

- Direct shell execution
- Filesystem writes
- Config mutation
- Plugin installation
- Worktree creation
- Non-loopback app-server WebSocket
