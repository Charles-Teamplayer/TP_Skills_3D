#!/bin/bash
# write-quick-delib.sh — MAGI 간편 심의 기록
# Usage: ./write-quick-delib.sh <type> <risk> <title> <result> <summary>
# Example: ./write-quick-delib.sh "feature" "low" "검색 기능 추가" "approved" "전원 찬성"

set -euo pipefail

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <type> <risk> <title> <result> <summary>" >&2
  echo "  type:    feature|bugfix|refactor|infra|decision" >&2
  echo "  risk:    low|medium|high|critical" >&2
  echo "  title:   안건 제목" >&2
  echo "  result:  approved|rejected|deferred|conditional" >&2
  echo "  summary: 요약" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/write-deliberation.sh" \
  --type "$1" \
  --risk "$2" \
  --title "$3" \
  --result "$4" \
  --summary "$5"
