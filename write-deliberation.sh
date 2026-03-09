#!/bin/bash
# write-deliberation.sh — MAGI 심의 기록 작성
# 간편 기록용. 전체 토론 기록(phases/votes)은 Claude가 직접 작성.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DELIB_FILE="$SCRIPT_DIR/deliberations.json"

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

TIMESTAMP="$(date +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\(..\)$/:\1/')"
SESSION_ID="SESSION #$(date +%H%M)"

init_file() {
  cat > "$DELIB_FILE" <<'INIT'
{
  "version": "1.0",
  "last_updated": "",
  "total_deliberations": 0,
  "deliberations": []
}
INIT
}

if [[ ! -f "$DELIB_FILE" ]]; then
  init_file
fi

# Validate JSON
if command -v jq &>/dev/null; then
  jq empty "$DELIB_FILE" 2>/dev/null || init_file
else
  python3 -c "import json; json.load(open('$DELIB_FILE'))" 2>/dev/null || init_file
fi

# Ensure object wrapper format (not bare array)
if command -v jq &>/dev/null; then
  IS_ARRAY=$(jq 'type == "array"' "$DELIB_FILE")
  if [[ "$IS_ARRAY" == "true" ]]; then
    TMPFILE=$(mktemp)
    jq '{version:"1.0",last_updated:"",total_deliberations:length,deliberations:.}' "$DELIB_FILE" > "$TMPFILE" && mv "$TMPFILE" "$DELIB_FILE"
  fi
fi

# Get next ID
if command -v jq &>/dev/null; then
  COUNT=$(jq '.total_deliberations // (.deliberations | length) // 0' "$DELIB_FILE")
else
  COUNT=$(python3 -c "import json;d=json.load(open('$DELIB_FILE'));print(d.get('total_deliberations',len(d.get('deliberations',[]))))")
fi

NEXT=$((COUNT + 1))
DELIB_ID=$(printf "delib-%03d" "$NEXT")

# Write in council.html-compatible nested format
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
    '.last_updated = $ts |
     .total_deliberations += 1 |
     .deliberations += [{
       id: $id,
       timestamp: $ts,
       session_id: $sid,
       agenda: {
         title: $title,
         description: $title,
         type: $type,
         risk: $risk,
         project: $project,
         triggered_by: $trigger
       },
       phases: { statements: [], cross_debate: [], votes: [] },
       verdict: {
         result: $result,
         summary: $summary,
         vetoes: []
       },
       status: "completed"
     }]' "$DELIB_FILE" > "$TMPFILE" && mv "$TMPFILE" "$DELIB_FILE"
else
  python3 - "$DELIB_FILE" "$DELIB_ID" "$TIMESTAMP" "$SESSION_ID" "$TITLE" "$TYPE" "$RISK" "$PROJECT" "$TRIGGER" "$RESULT" "$SUMMARY" <<'PYEOF'
import json, sys
path, did, ts, sid, title, typ, risk, proj, trig, res, summ = sys.argv[1:]
with open(path) as f:
    data = json.load(f)
if isinstance(data, list):
    data = {"version":"1.0","last_updated":"","total_deliberations":len(data),"deliberations":data}
data["last_updated"] = ts
data["total_deliberations"] = data.get("total_deliberations", 0) + 1
data["deliberations"].append({
    "id": did, "timestamp": ts, "session_id": sid,
    "agenda": {"title":title,"description":title,"type":typ,"risk":risk,"project":proj,"triggered_by":trig},
    "phases": {"statements":[],"cross_debate":[],"votes":[]},
    "verdict": {"result":res,"summary":summ,"vetoes":[]},
    "status": "completed"
})
with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEOF
fi

echo "$DELIB_ID written to $DELIB_FILE"
