#!/bin/sh
# Installs the Lua language server (LuaLS) and the WoW API annotations it checks
# against into ./.luals (project-local, gitignored). CI runs this same script.
# Afterwards run: sh scripts/check-types.sh
#
# Both are pinned here. Dependabot can't see them, so bump them by hand: change
# the version and its sha256 (from the release page) or the commit, then rerun.
set -eu
cd "$(dirname "$0")/.."

LUALS_VERSION=3.19.2
LUALS_SHA256_LINUX_X64=93ad326b10f6c00911dd8c450fa098332dbd8f9f45d1052f5636a2d54479b947
LUALS_SHA256_DARWIN_ARM64=79149584320a23bd5fcd5bc31f47a1975acd8a4560a0e89036bb1016fa61687f

# Ketho/vscode-wow-api tag 0.22.3. Fetching by commit checks the content, so the
# pin can't be swapped behind our back. Only Annotations/Core is needed (the
# FrameXML submodule is Blizzard's UI code, not the API).
ANNOTATIONS_REPO=https://github.com/Ketho/vscode-wow-api.git
ANNOTATIONS_COMMIT=56fbef8adacfe978b4b6eea5fdb6fab4bb707e2b

dir=.luals
mkdir -p "$dir"

# LuaLS
stamp="$dir/luals/.version"
if [ "$(cat "$stamp" 2>/dev/null)" = "$LUALS_VERSION" ]; then
  echo "LuaLS $LUALS_VERSION already installed."
else
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) platform=linux-x64 sha=$LUALS_SHA256_LINUX_X64 ;;
    Darwin-arm64) platform=darwin-arm64 sha=$LUALS_SHA256_DARWIN_ARM64 ;;
    *) echo "No pinned LuaLS build for $(uname -s)-$(uname -m). Add its sha256 to $0."; exit 1 ;;
  esac
  tarball="$dir/luals.tar.gz"
  curl -fsSL -o "$tarball" \
    "https://github.com/LuaLS/lua-language-server/releases/download/$LUALS_VERSION/lua-language-server-$LUALS_VERSION-$platform.tar.gz"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "$sha  $tarball" | sha256sum -c -
  else
    echo "$sha  $tarball" | shasum -a 256 -c -
  fi
  rm -rf "$dir/luals"
  mkdir -p "$dir/luals"
  tar -xzf "$tarball" -C "$dir/luals"
  rm -f "$tarball"
  echo "$LUALS_VERSION" > "$stamp"
fi

# WoW API annotations
api="$dir/wow-api"
if [ "$(git -C "$api" rev-parse HEAD 2>/dev/null)" = "$ANNOTATIONS_COMMIT" ]; then
  echo "WoW API annotations $ANNOTATIONS_COMMIT already present."
else
  rm -rf "$api"
  git init -q "$api"
  git -C "$api" sparse-checkout set Annotations/Core
  git -C "$api" fetch -q --depth 1 "$ANNOTATIONS_REPO" "$ANNOTATIONS_COMMIT"
  git -C "$api" -c advice.detachedHead=false checkout -q FETCH_HEAD
  if [ "$(git -C "$api" rev-parse HEAD)" != "$ANNOTATIONS_COMMIT" ]; then
    echo "Fetched annotations don't match $ANNOTATIONS_COMMIT."
    exit 1
  fi
fi

echo "Done. Run: sh scripts/check-types.sh"
