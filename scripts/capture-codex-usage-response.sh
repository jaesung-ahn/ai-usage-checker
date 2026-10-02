#!/bin/bash
# Codex 사용량 엔드포인트를 한 번 호출해 응답을 저장한다.
# 픽스처를 만들기 위한 일회성 도구다.
#
# 토큰과 계정 ID는 출력하지 않고 저장하지도 않는다. 저장되는 것은 응답 본문뿐이다.
# 응답에는 계정·사용자 식별자가 들어 있다. 픽스처로 옮기기 전에 지운다.
set -euo pipefail

OUT="${1:-$HOME/.ai-usage-checker/codex-usage-response.json}"
mkdir -p "$(dirname "$OUT")"

AUTH="$HOME/.codex/auth.json"
if [ ! -f "$AUTH" ]; then
  echo "$AUTH 가 없습니다. codex 로그인 상태를 확인하세요." >&2
  exit 1
fi

umask 077
HEADERS="$(mktemp)"
trap 'rm -f "$HEADERS"' EXIT

# 토큰을 명령줄 인자로 넘기지 않는다. 프로세스 목록에 보이지 않게 헤더 파일로 전달한다.
python3 - "$AUTH" > "$HEADERS" <<'PY'
import json, sys

with open(sys.argv[1]) as handle:
    tokens = json.load(handle).get("tokens") or {}

token = tokens.get("access_token")
if not token:
    raise SystemExit("access_token이 없습니다")

print(f"Authorization: Bearer {token}")
if tokens.get("account_id"):
    print(f"ChatGPT-Account-Id: {tokens['account_id']}")
PY

STATUS=$(curl -sS -o "$OUT" -w '%{http_code}' \
  https://chatgpt.com/backend-api/wham/usage \
  -H @"$HEADERS" \
  -H "User-Agent: codex-cli" \
  -H "Accept: application/json")

echo "HTTP $STATUS"
echo "저장 위치: $OUT"
