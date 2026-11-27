#!/bin/sh
# Fails when line coverage in luacov.report.out is below the minimum, for the
# total and for each measured file (.luacov), so a well-covered file can't
# hide one that dropped. LuaCov has no built-in minimum, so this reads the
# summary table it writes.
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

# Files below the minimum: summary rows are "<file> <hits> <missed> <percent>%".
low=$(awk -v m="$min" '
  /^Summary/ { on = 1; next }
  on && NF == 4 && $4 ~ /%$/ && $1 != "Total" {
    p = $4; gsub("%", "", p)
    if (p + 0 < m + 0) print $1 " (" $4 ")"
  }' "$report")

if [ -n "$low" ]; then
  echo "Coverage is below the minimum of ${min}% in:"
  echo "$low" | sed 's/^/  /'
  echo "Add busted specs for the new code."
  exit 1
fi

if awk -v t="$total" -v m="$min" 'BEGIN { exit !(t + 0 < m + 0) }'; then
  echo "Coverage ${total}% is below the minimum of ${min}%. Add busted specs for the new code."
  exit 1
fi

echo "Coverage check: OK (every file and the total ${total}% >= ${min}%)"
