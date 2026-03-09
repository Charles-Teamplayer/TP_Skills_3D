#!/bin/bash
# write-deliberation.sh — MAGI 심의 기록 작성
# Usage: ./write-deliberation.sh --title "제목" --type "feature" --risk "low" ...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DELIB_FILE="$SCRIPT_DIR/deliberations.json"

# Defaults
TITLE="" TYPE="feature" RISK="low" PROJECT="" TRIGGER="CEO" RESULT="approved" SUMMARY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)   TITLE="$2";   shift 2 ;;
    --type)    TYPE="$2";    shift 2 ;;
    --risk)    RISK="$2";    shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --trigger) TRIGGER="$2"; shift 2 ;;
    --result)  RESULT="$2";  shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$TITLE" ]]; then
  echo "Error: --title is required" >&2
  exit 1
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SESSION_ID="session-$(date +%Y%m%d)-$$"

# Initialize file if missing or invalid
init_file() {
  cat > "$DELIB_FILE" <<'INIT'
{
  "total_deliberations": 0,
  "deliberations": []
}
INIT
}

if [[ ! -f "$DELIB_FILE" ]]; then
  init_file
fi

# Validate JSON; reinit if corrupt
if command -v jq &>/dev/null; then
  jq empty "$DELIB_FILE" 2>/dev/null || init_file
else
  python3 -c "import json; json.load(open('$DELIB_FILE'))" 2>/dev/null || init_file
fi

# Get next ID
if command -v jq &>/dev/null; then
  COUNT=$(jq '.total_deliberations // 0' "$DELIB_FILE")
else
  COUNT=$(python3 -c "import json; print(json.load(open('$DELIB_FILE')).get('total_deliberations',0))")
fi

NEXT=$((COUNT + 1))
DELIB_ID=$(printf "delib-%03d" "$NEXT")

# Write with jq or python3
if command -v jq &>/dev/null; then
  TMPFILE=$(mktemp)
  jq \
    --arg id "$DELIB_ID" \
    --arg ts "$TIMESTAMP" \
    --arg sid "$SESSION_ID" \
    --arg title "$TITLE" \
    --arg type "$TYPE" \
    --arg risk "$RISK" \
    --arg project "$PROJECT" \
    --arg trigger "$TRIGGER" \
    --arg result "$RESULT" \
    --arg summary "$SUMMARY" \
    '.total_deliberations += 1 |
     .deliberations += [{
       id: $id,
       timestamp: $ts,
       session_id: $sid,
       title: $title,
       type: $type,
       risk_level: $risk,
       project: $project,
       trigger: $trigger,
       result: $result,
       summary: $summary
     }]' "$DELIB_FILE" > "$TMPFILE" && mv "$TMPFILE" "$DELIB_FILE"
else
  python3 - "$DELIB_FILE" "$DELIB_ID" "$TIMESTAMP" "$SESSION_ID" "$TITLE" "$TYPE" "$RISK" "$PROJECT" "$TRIGGER" "$RESULT" "$SUMMARY" <<'PYEOF'
import json, sys
path, did, ts, sid, title, typ, risk, proj, trig, res, summ = sys.argv[1:]
with open(path) as f:
    data = json.load(f)
data["total_deliberations"] = data.get("total_deliberations", 0) + 1
data["deliberations"].append({
    "id": did, "timestamp": ts, "session_id": sid,
    "title": title, "type": typ, "risk_level": risk,
    "project": proj, "trigger": trig, "result": res, "summary": summ
})
with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEOF
fi

echo "$DELIB_ID written to $DELIB_FILE"
