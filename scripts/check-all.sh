#!/bin/sh
# Runs every CI check that works offline, reports each one, and fails if any
# failed. The zip check needs the BigWigs packager, so it runs in CI only.
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

if [ -n "$failed" ]; then
  echo "FAILED:$failed"
  exit 1
fi
echo "All checks passed."
