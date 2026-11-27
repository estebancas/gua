#!/bin/sh
# Runs every CI check that works offline, reports each one, and fails if any
# failed. The zip check needs the BigWigs packager, so it runs in CI only.
# The LuaLS type check runs once scripts/setup-luals.sh has installed it.
# zizmor, actionlint and gitleaks run when installed (brew install zizmor
# actionlint gitleaks) and are skipped with a note otherwise; CI always runs them.
# Usage (repo root, with .lua/bin on PATH): sh scripts/check-all.sh
set -u

failed=""

run() {
  name="$1"
  shift
  echo "==> $name"
  if ! "$@"; then
    failed="$failed $name"
  fi
}

run luacheck luacheck . -q
run tests sh scripts/test.sh
run forbidden-api lua scripts/check-forbidden-api.lua
run toc lua scripts/check-toc.lua

# Like run, but skips the check with a note when the tool isn't installed.
optional() {
  if command -v "$2" >/dev/null 2>&1; then
    run "$@"
  else
    echo "==> $1: skipped ($2 not installed; CI runs it)"
  fi
}

# LuaLS lives in .luals (scripts/setup-luals.sh), not on PATH.
if [ -x .luals/luals/bin/lua-language-server ]; then
  run types sh scripts/check-types.sh
else
  echo "==> types: skipped (run sh scripts/setup-luals.sh; CI runs it)"
fi

optional zizmor zizmor --offline --no-progress --quiet .
optional actionlint actionlint
optional gitleaks-history gitleaks git --verbose --redact --exit-code 1 --no-banner --log-level warn --log-opts=HEAD .
optional gitleaks-uncommitted gitleaks git --pre-commit --verbose --redact --exit-code 1 --no-banner --log-level warn .

if [ -n "$failed" ]; then
  echo "FAILED:$failed"
  exit 1
fi
echo "All checks passed."
