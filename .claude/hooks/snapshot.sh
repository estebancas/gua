#!/bin/sh
# UserPromptSubmit hook: remember the working tree at the start of the turn,
# so the Stop hook runs the checks only when this turn changed something.
. "$(dirname "$0")/lib.sh"

tree_hash > "$snap"
rm -f "$blocks"
exit 0
