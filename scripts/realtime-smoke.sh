#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "OPENAI_API_KEY is not set" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

code="$(
  curl -sS -o "$tmp" -w '%{http_code}' https://api.openai.com/v1/realtime/sessions \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H 'Content-Type: application/json' \
    -d '{"model":"gpt-realtime-1.5","modalities":["audio","text"]}'
)"

echo "HTTP_STATUS=$code"
python3 - "$tmp" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
print("HAS_CLIENT_SECRET=" + str(bool(data.get("client_secret"))))
print("MODEL=" + str(data.get("model")))
if "error" in data:
    err = data["error"]
    print("ERROR_TYPE=" + str(err.get("type")))
    print("ERROR_CODE=" + str(err.get("code")))
    print("ERROR_MESSAGE=" + str(err.get("message"))[:300])
PY
