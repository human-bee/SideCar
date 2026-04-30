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

## Live Codex Probe

On launch, SideCar tries to probe the bundled Codex app binary at:

```text
/Applications/Codex.app/Contents/Resources/codex
```

SideCar currently tries the app-server proxy first, then falls back to direct `stdio://` app-server. Live mode performs initialize, `thread/list`, and `thread/read` for recent thread snapshots. Continuous event streaming is the next integration milestone.

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

The Talk dock includes a Screen Recording permission request. Captured visual context must remain preview-gated before model send.
