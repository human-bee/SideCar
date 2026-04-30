# Contributing

SideCar is package-first during MVP.

## Local Checks

```bash
swift test
```

The current MVP has a known Swift 6 sendability build blocker in `VoiceCore`. Do not mark a pull request ready until `swift test` runs cleanly on the same command used by CI.

## Safety Rules

- Do not add direct shell execution, filesystem writes, config writes, plugin installation, or worktree creation without updating the action-gate contract and tests.
- Do not commit private Codex rollouts, sqlite databases, screenshots, API keys, or `.env` files.
- New Codex payload shapes should be added as sanitized fixtures and parser tests.
- UI changes should preserve the status-summary-evidence hierarchy.
