#!/bin/sh
# Fails when the packaged zip holds any file outside the allowlist: the .toc,
# the files it lists, and the docs players should get. Catches dev files
# (plans, agent notes, specs) leaking into the CurseForge download.
# Usage (repo root, after the packager ran with -d): sh scripts/check-package.sh [ZIP]
set -eu

toc="gua.toc"
zip="${1:-}"

if [ -z "$zip" ]; then
  set -- .release/*.zip
  if [ ! -f "$1" ]; then
    echo "No zip in .release/. Run the BigWigs packager with -d first."
    exit 1
  fi
  if [ "$#" -ne 1 ]; then
    echo "Several zips in .release/; pass the one to check: $*"
    exit 1
  fi
  zip="$1"
fi

required=$(mktemp)
allowed=$(mktemp)
actual=$(mktemp)
trap 'rm -f "$required" "$allowed" "$actual"' EXIT

# Must be in the zip: the .toc and every file it lists.
{
  echo "gua/$toc"
  sed -e 's/\r$//' -e 's/\\/\//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$toc" |
    grep -v -e '^#' -e '^$' |
    sed 's/^/gua\//'
} | sort -u > "$required"

# May be in the zip: the required files, their folders, and docs for players.
{
  cat "$required"
  echo "gua/"
  echo "gua/README.md"
  echo "gua/CHANGELOG.md"
  echo "gua/LICENSE"
  echo "gua/LICENSE.md"
  # Each parent folder of nested .toc entries.
  sed 's/^gua\///' "$required" |
    awk '{ n = split($0, part, "/"); dir = "gua/"; for (i = 1; i < n; i++) { dir = dir part[i] "/"; print dir } }'
} | sort -u > "$allowed"

unzip -Z1 "$zip" | sort -u > "$actual"

status=0

missing=$(comm -23 "$required" "$actual")
if [ -n "$missing" ]; then
  echo "The package is missing files that $toc loads, so the addon would fail in game:"
  echo "$missing" | sed 's/^/  /'
  echo "Check 'ignore:' in .pkgmeta: it must not cover files listed in $toc."
  status=1
fi

extra=$(comm -13 "$allowed" "$actual")
if [ -n "$extra" ]; then
  echo "The package contains files that are not on the allowlist:"
  echo "$extra" | sed 's/^/  /'
  echo "Add them to 'ignore:' in .pkgmeta, or, if players need them, list them in $toc"
  echo "or in scripts/check-package.sh (a risky change: it needs the owner's review)."
  status=1
fi

if [ "$status" -ne 0 ]; then
  exit 1
fi

echo "Package check: OK ($(wc -l < "$actual" | tr -d ' ') entries in $(basename "$zip"))"
