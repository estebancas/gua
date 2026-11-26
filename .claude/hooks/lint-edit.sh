#!/bin/sh
# PostToolUse hook (Edit|Write|MultiEdit): lint the edited Lua file right away.
# Exit 2 sends luacheck's warnings back to the agent so it fixes them now.
. "$(dirname "$0")/lib.sh"

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
case "$file" in
  "$root"/*.lua) rel=${file#"$root"/} ;;
  *) exit 0 ;;
esac
case "$rel" in
  .lua/*) exit 0 ;;
esac
[ -f "$rel" ] || exit 0

if [ ! -x .lua/bin/luacheck ]; then
  echo "luacheck is not installed in .lua/. Run: sh scripts/setup-dev.sh" >&2
  exit 2
fi

if ! out=$(.lua/bin/luacheck --no-color -q "$rel" 2>&1); then
  printf 'luacheck found problems in %s. Fix them (never weaken .luacheckrc to hide them):\n%s\n' "$rel" "$out" >&2
  exit 2
fi
exit 0
