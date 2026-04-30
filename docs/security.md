# Security Boundaries

SideCar is designed as a local-first companion. The MVP should be safe to run in fixture mode without private Codex state, secrets, or network access beyond normal toolchain dependency resolution.

## Explicitly Out Of Scope

The MVP must not add:

- direct shell execution
- arbitrary filesystem writes
- Codex config writes
- plugin installation
- worktree creation
- non-loopback app-server WebSocket connections
- silent screen capture
- long-lived API keys in browser-style clients

Future work in any of these areas requires a documented action-gate contract, tests, and user-visible confirmation.

## Secrets

- Prefer Keychain for `OPENAI_API_KEY`.
- `.env` files are for local development only.
- Never commit real keys, Codex sqlite databases, private rollouts, screenshots with sensitive content, or generated diagnostics containing secrets.
- Do not print secret values in logs or CI output.

## Network And Codex Access

Live Codex integration should only talk to loopback app-server endpoints. Unsupported methods or payloads must degrade visibly instead of falling back to broader local access.

## Screen Context

Screen capture is permissioned, on-demand, and preview-gated. SideCar should not send visual context to a model until the user has seen and accepted the capture for that session.
