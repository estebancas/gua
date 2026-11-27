#!/bin/sh
# Type-checks the addon's WoW API calls with LuaLS (settings in .luarc.json):
# unknown functions, wrong or missing arguments, nil used as a value.
# Needs scripts/setup-luals.sh to have run once. Fails if LuaLS reports anything.
# Usage (repo root): sh scripts/check-types.sh
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)

luals=.luals/luals/bin/lua-language-server
if [ ! -x "$luals" ]; then
  echo "LuaLS is not installed. Run: sh scripts/setup-luals.sh"
  exit 1
fi

logs=$(mktemp -d)
trap 'rm -rf "$logs"' EXIT

# LuaLS exits non-zero when it finds problems, so judge by its report instead.
# A missing report means it didn't run properly: that's a failure, not a pass.
status=0
"$luals" --check "$root" --checklevel=Warning --check_format=json --logpath "$logs" >"$logs/out.txt" 2>&1 || status=$?
report="$logs/check.json"
if [ ! -f "$report" ]; then
  cat "$logs/out.txt"
  echo "Type check: LuaLS wrote no report (exit $status)."
  exit 1
fi
if [ "$(jq 'length' "$report")" = 0 ]; then
  echo "Type check: OK"
  exit 0
fi

# One line per finding: file:line:col code: message
findings=$(jq -r --arg root "file://$root/" '
  to_entries[] | (.key | ltrimstr($root)) as $file | .value[] |
  "\($file):\(.range.start.line + 1):\(.range.start.character + 1) \(.code): \(.message | gsub("\n"; " "))"
' "$report")
echo "$findings"

if [ -n "${GITHUB_ACTIONS:-}" ]; then
  echo "$findings" | while IFS= read -r line; do
    loc=${line%% *}
    file=${loc%%:*}
    rest=${loc#*:}
    echo "::warning file=$file,line=${rest%%:*},title=LuaLS::${line#* }"
  done
fi

echo "Type check: $(echo "$findings" | wc -l | tr -d ' ') finding(s). Fix the code; for a real Forever difference, see CLAUDE.md."
exit 1
