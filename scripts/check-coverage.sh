#!/bin/sh
# Fails when line coverage in luacov.report.out is below the minimum.
# LuaCov has no built-in minimum, so this reads the "Total" line it writes.
# Usage (repo root): busted --coverage && luacov && sh scripts/check-coverage.sh [MIN]
set -eu

min="${1:-90}"
report="luacov.report.out"

if [ ! -f "$report" ]; then
  echo "$report not found. Run 'busted --coverage' and then 'luacov' first."
  exit 1
fi

# Summary line: "Total   <hits>   <missed>   <percent>%"
total=$(awk '$1 == "Total" { gsub("%", "", $4); print $4 }' "$report" | tail -n 1)

if [ -z "$total" ]; then
  echo "No 'Total' line in $report. Check the include list in .luacov."
  exit 1
fi

# Per-file lines, so a failure says where coverage is missing.
awk '/^Summary/ { on = 1 } on' "$report"

if awk -v t="$total" -v m="$min" 'BEGIN { exit !(t + 0 < m + 0) }'; then
  echo "Coverage ${total}% is below the minimum of ${min}%. Add busted specs for the new code in Logic.lua."
  exit 1
fi

echo "Coverage check: OK (${total}% >= ${min}%)"
