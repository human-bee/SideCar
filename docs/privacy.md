# Privacy

SideCar is local-first by default.

## Local Data

Thread snapshots, fixture captures, diagnostics, and settings should remain on-device unless the user manually exports them.

## OpenAI Keys

The MVP uses a BYO OpenAI API key stored in Keychain. Lookup is Keychain-first, then `OPENAI_API_KEY` from the process environment, then a local `.env` fallback for development.

`.env` files are user-owned and must not be committed, rewritten, or printed. Tests should use the injected key-source seam with fake values instead of requiring a real OpenAI key.

## Voice

Realtime voice uses ephemeral session credentials minted by the native app broker. Long-lived API keys are not sent to browser-style realtime clients. UI surfaces should consume the session status model and display only availability, minting, active, or failure state; they must not render key material or raw secrets.

## Screen Capture

Screen capture requires explicit macOS permission. SideCar should show a preview before sending any visual context to a model for the first time in a session.

## Telemetry

Telemetry is off by default. Public releases may add opt-in telemetry only after explicit consent.
