# Contributing

SideCar is a SwiftPM-first macOS app during MVP. The canonical local review path is `swift test`, then `make app`, then `open -n dist/SideCar.app`.

## Local Checks

```bash
swift test
make app
open -n dist/SideCar.app
```

Do not mark a pull request ready until `swift test` runs cleanly on the same command used by CI. UI or app lifecycle changes should also smoke test the local debug bundle with `open -n dist/SideCar.app`.

## Safety Rules

- Do not add direct shell execution, filesystem writes, config writes, plugin installation, or worktree creation without updating the action-gate contract and tests.
- Do not commit private Codex rollouts, sqlite databases, screenshots, API keys, or `.env` files.
- New Codex payload shapes should be added as sanitized fixtures and parser tests.
- UI changes should preserve the status-summary-evidence hierarchy.
- Keep generated local bundles under `dist/`; release signing and notarization belong in a separate packaging change.
