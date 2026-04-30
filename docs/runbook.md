# MVP Runbook

## Build And Test

```bash
swift test
swift build
```

## Run Fixture Mode

```bash
swift run SideCar
```

The floating panel opens with fixture data. This mode does not require Codex Desktop, Codex++, Screen Recording, or an OpenAI key.

## Build A Local Debug App

```bash
make app
open -n dist/SideCar.app
```

This creates an unsigned local review bundle at `dist/SideCar.app`. It is useful for smoke testing app lifecycle behavior through LaunchServices. It is not a notarized release artifact.

## Live Codex Probe

On launch, SideCar tries to probe the bundled Codex app binary at:

```text
/Applications/Codex.app/Contents/Resources/codex
```

SideCar currently tries the app-server proxy first, then falls back to direct `stdio://` app-server. Live mode performs initialize and bounded `thread/list` loading for recent thread snapshots. `CodexAdapter` includes tested stream-reader and reducer contracts for app-server notifications; wiring that reader into a persistent live app session is the next integration milestone.

Confirmed live actions are not retried after a post-request failure. This avoids replaying side effects such as `turn/start`, `turn/steer`, or `thread/fork` if the proxy path sent the request but response parsing failed.

`/side` is a first-class SideCar primitive. In this build, live execution maps it to a guarded `thread/fork` with `persistExtendedHistory: false` and developer instructions that treat the parent history as read-only reference context. Replace that adapter method when Codex app-server exposes a dedicated `/side` request.

Approval cards are draft-only in this build. The app-server approval flow is server-initiated JSON-RPC request/response. SideCar can decode command/file approval requests and encode accept/decline responses with the same request id, but live execution still needs same-connection response plumbing before it can be enabled safely.

## OpenAI Key

The Realtime broker checks Keychain first. For local development only, `OPENAI_API_KEY` may be provided in the process environment or a local `.env`.

Do not commit `.env` files, and do not print API key values in logs or test output.

Realtime/OpenAI tests should use the injectable API-key source and session transport. Use `StaticOpenAIAPIKeySource` plus a stub `RealtimeSessionTransport` for unit coverage of:

- no-key behavior;
- session status transitions for UI integration;
- model/session availability failures returned by the Realtime session endpoint.

Only manual smoke tests should use a real key. A successful manual mint should return an active status for `gpt-realtime-1.5`; a 4xx response should be treated as unavailable or misconfigured without exposing the request key.

Manual smoke test without printing secrets:

```bash
tmp=$(mktemp)
code=$(curl -sS -o "$tmp" -w '%{http_code}' https://api.openai.com/v1/realtime/sessions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-realtime-1.5","modalities":["audio","text"]}')
echo "HTTP_STATUS=$code"
python3 - "$tmp" <<'PY'
import json, sys
data=json.load(open(sys.argv[1]))
print("HAS_CLIENT_SECRET=" + str(bool(data.get("client_secret"))))
print("MODEL=" + str(data.get("model")))
PY
rm -f "$tmp"
```

## Screen Capture

The Talk dock includes Realtime readiness checks, a Screen Recording permission request, capture preview, accept preview, and clear preview controls. Option-Shift-Space opens Talk mode and checks Realtime readiness. Captured visual context remains preview-gated and is not automatically sent to a model.
