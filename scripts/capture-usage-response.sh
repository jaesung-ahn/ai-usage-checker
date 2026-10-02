#!/bin/bash
# OAuth usage 엔드포인트를 한 번 호출해 응답을 저장한다.
# docs/spec/fixtures 에 넣을 픽스처를 만들기 위한 일회성 도구다.
#
# 토큰은 출력하지 않고 저장하지도 않는다. 저장되는 것은 응답 본문뿐이다.
set -euo pipefail

OUT="${1:-$HOME/.ai-usage-checker/usage-response.json}"
mkdir -p "$(dirname "$OUT")"

read_token() {
  local file="$HOME/.claude/.credentials.json"

  if [ -f "$file" ]; then
    python3 - "$file" <<'PY'
import json, sys

with open(sys.argv[1]) as handle:
    data = json.load(handle)

oauth = data.get("claudeAiOauth") or data
print(oauth.get("accessToken", ""))
PY
    return
  fi

  # 파일이 없으면 Keychain을 본다. 최초 접근 시 macOS 권한 창이 뜬다.
  security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c '
import json, sys

raw = sys.stdin.read().strip()
try:
    data = json.loads(raw)
except Exception:
    print(raw)
    raise SystemExit

oauth = data.get("claudeAiOauth") or data
print(oauth.get("accessToken", ""))
'
}

TOKEN="$(read_token)"
if [ -z "$TOKEN" ]; then
  echo "토큰을 찾지 못했습니다. claude 로그인 상태를 확인하세요." >&2
  exit 1
fi

umask 077
STATUS=$(curl -sS -o "$OUT" -w '%{http_code}' \
  https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "Accept: application/json")

echo "HTTP $STATUS"
echo "저장 위치: $OUT"
