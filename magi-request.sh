#!/bin/bash
# magi-request.sh — MAGI Council 승인 요청 (GitHub Issue 생성)
# Usage: ./magi-request.sh --title "안건" --type feature --risk low --project "프로젝트" --summary "요약"

set -euo pipefail

TITLE="" TYPE="decision" RISK="medium" PROJECT="" SUMMARY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)   TITLE="$2";   shift 2 ;;
    --type)    TYPE="$2";    shift 2 ;;
    --risk)    RISK="$2";    shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$TITLE" ]]; then
  echo "Error: --title required" >&2
  echo "Usage: $0 --title \"안건\" --type feature --risk low --project \"프로젝트\" --summary \"요약\"" >&2
  exit 1
fi

REPO="Charles-Teamplayer/TP_Skills_3D"

BODY="## MAGI Council 승인 요청

AGENDA: ${TITLE}
TYPE: ${TYPE}
RISK: ${RISK}
PROJECT: ${PROJECT}

### MAGI 심의 요약
${SUMMARY}

---
### 승인 방법
\`승인\` / \`APPROVE\` / \`可\` — 승인
\`거부\` / \`REJECT\` / \`否\` — 거부
\`보류\` / \`HOLD\` / \`留\` — 보류

> MAGI Council: https://charles-teamplayer.github.io/TP_Skills_3D/council.html"

# Create GitHub Issue
ISSUE_URL=$(gh issue create \
  --repo "$REPO" \
  --title "🔒 [MAGI] ${TITLE}" \
  --body "$BODY" \
  --label "magi-approval" 2>&1)

echo "✅ 승인 요청 생성: $ISSUE_URL"
echo "CEO가 Issue 코멘트에 '승인' 또는 '거부'를 입력하면 자동 처리됩니다."
