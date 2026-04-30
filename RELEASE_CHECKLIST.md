# Release Checklist

## Preflight

- [ ] `swift test`
- [ ] `swift run SideCar` launches without beachballing or crashing.
- [ ] `make app && open -n dist/SideCar.app` launches without beachballing or crashing.
- [ ] Fixture mode works with Codex Desktop closed.
- [ ] Live mode loads recent threads with Codex Desktop open.
- [ ] Realtime session smoke test returns HTTP 200 for `gpt-realtime-1.5` without printing secrets.
- [ ] `.env`, private rollouts, sqlite databases, screenshots, and generated diagnostics are not tracked.

## GitHub

- [ ] Create repository.
- [ ] Push `main`.
- [ ] Confirm GitHub Actions `swift test` passes.
- [ ] Add README screenshots only after redaction.
- [ ] File issues for known gaps: long-lived event reader, audio loop, signed packaging, Codex++ bridge.

## Packaging

- [ ] Promote the debug bundle script to a signed release packaging flow.
- [ ] Hardened runtime.
- [ ] Notarization.
- [ ] Optional Homebrew Cask after first signed GitHub release.

## Security

- [ ] Re-review `docs/security.md`.
- [ ] Confirm no unsafe app-server methods are exposed.
- [ ] Confirm live side-effect actions are not retried after request failure.
- [ ] Confirm approval cards remain draft-only until server-request response plumbing exists.
- [ ] Confirm visual context remains preview-gated.
- [ ] Confirm API keys are Keychain/env only and never logged.
