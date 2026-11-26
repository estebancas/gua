#!/bin/sh
# Stop hook: before the agent finishes a turn that changed files, run every
# offline CI check (scripts/check-all.sh). Exit 2 blocks the stop and sends
# the failures back to the agent. After MAX_BLOCKS blocks in one turn it lets
# the agent stop and warns the user instead, so a failure it can't fix doesn't
# loop forever.
. "$(dirname "$0")/lib.sh"
MAX_BLOCKS=3

now=$(tree_hash)
if [ -f "$snap" ] && [ "$(cat "$snap")" = "$now" ]; then
  exit 0 # nothing changed this turn
fi

if [ -x .lua/bin/luacheck ] && [ -x .lua/bin/busted ]; then
  out=$(PATH="$root/.lua/bin:$PATH" sh scripts/check-all.sh 2>&1) && {
    echo "$now" > "$snap"
    rm -f "$blocks"
    exit 0
  }
else
  out="The Lua tools are not installed in .lua/. Run: sh scripts/setup-dev.sh"
fi

n=$(( $(cat "$blocks" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$blocks"

if [ "$n" -gt "$MAX_BLOCKS" ]; then
  summary=$(printf '%s\n' "$out" | grep '^FAILED:' || echo "see sh scripts/check-all.sh")
  jq -n --arg m "gua checks still fail after $MAX_BLOCKS tries ($summary). Run sh scripts/check-all.sh." \
    '{systemMessage: $m}'
  exit 0
fi

{
  echo "The gua checks failed (scripts/check-all.sh). Last lines:"
  printf '%s\n' "$out" | tail -n 60
  echo
  echo "Fix these before finishing. Never weaken a check to make it pass."
  echo "If a failure comes from changes you did not make, stop and tell the user."
} >&2
exit 2
