#!/bin/sh
# Symlinks this folder into the game's AddOns folder as "gua".
# Override the game location with: WOW_DIR="/path/to/_forever_" scripts/link.sh
set -eu

WOW_DIR="${WOW_DIR:-/Applications/World of Warcraft/_forever_}"
ADDONS_DIR="$WOW_DIR/Interface/AddOns"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ADDONS_DIR/gua"

if [ ! -d "$ADDONS_DIR" ]; then
  echo "AddOns folder not found: $ADDONS_DIR" >&2
  echo "Set WOW_DIR to your _forever_ folder." >&2
  exit 1
fi

if [ -L "$DEST" ] && [ "$(readlink "$DEST")" = "$SRC" ]; then
  echo "Already linked: $DEST -> $SRC"
  exit 0
fi

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  echo "Something else is already at $DEST. Remove it first." >&2
  exit 1
fi

ln -s "$SRC" "$DEST"
echo "Linked: $DEST -> $SRC"
