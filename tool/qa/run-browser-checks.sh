#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p .tmp/preview
export TMPDIR="$PWD/.tmp" TMP="$PWD/.tmp" TEMP="$PWD/.tmp"
ln -sfn "$PWD/build/web" .tmp/preview/SillyTavern
python3 -m http.server 8089 --bind 127.0.0.1 --directory .tmp/preview > .tmp/browser-server.log 2>&1 &
qa_server_pid=$!
trap 'kill "$qa_server_pid" 2>/dev/null || true' EXIT
python3 - <<'PY'
import time, urllib.request
for attempt in range(30):
    try:
        with urllib.request.urlopen('http://127.0.0.1:8089/SillyTavern/version.json', timeout=1) as response:
            if response.status == 200:
                break
    except OSError:
        time.sleep(.25)
else:
    raise SystemExit('Browser QA server did not start')
PY
kill -0 "$qa_server_pid"
node tool/qa/compatible.e2e.cjs | tee .tmp/browser-compatible.log
node tool/qa/provider.e2e.cjs | tee .tmp/browser-provider.log
node tool/qa/multimodal.e2e.cjs | tee .tmp/browser-multimodal.log
