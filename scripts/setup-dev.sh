#!/bin/sh
# Installs Lua 5.1, luacheck, busted and luacov into ./.lua (project-local).
# CI runs this same script, so local runs and CI use the same versions.
# Afterwards run: . .lua/bin/activate
set -eu
cd "$(dirname "$0")/.."

# Every rock, dependencies included, at an exact version. Dependencies come
# first, so installing a tool finds them already there and downloads nothing
# else. To upgrade, change a version here (CI's cache key is this file's hash).
ROCKS="
luafilesystem 1.9.0-1
argparse 0.7.2-1
dkjson 2.11-1
lua-term 0.8-1
lua_cliargs 3.0.2-1
luasystem 0.7.1-1
mediator_lua 1.1.2-0
penlight 1.15.0-1
say 1.4.1-3
luassert 1.9.0-1
datafile 0.11-1
luacheck 1.2.0-1
luacov 0.17.0-1
busted 2.3.0-1
"

# Python from python.org on macOS ships without CA certificates, which breaks
# hererocks downloads. Fall back to the system bundle when none is set.
if [ -z "${SSL_CERT_FILE:-}" ] && [ -f /etc/ssl/cert.pem ]; then
  export SSL_CERT_FILE=/etc/ssl/cert.pem
fi

python3 -m pip install --user hererocks==0.25.1
# --no-readline: the CI runner has no readline headers, and the tools don't need
# Lua's interactive prompt.
python3 -m hererocks .lua -l 5.1 -r 3.8.0 --no-readline

echo "$ROCKS" | while read -r name version; do
  if [ -n "$name" ]; then
    .lua/bin/luarocks install "$name" "$version"
  fi
done

# Fail if anything not pinned above was installed, or a version differs.
expected=$(echo "$ROCKS" | awk 'NF == 2 { print $1 " " $2 }' | sort)
installed=$(.lua/bin/luarocks list --porcelain | awk '{ print $1 " " $2 }' | sort)
if [ "$expected" != "$installed" ]; then
  echo "Installed rocks differ from the pinned list in scripts/setup-dev.sh."
  echo "Pinned:"
  echo "$expected" | sed 's/^/  /'
  echo "Installed:"
  echo "$installed" | sed 's/^/  /'
  exit 1
fi

echo "Done. Run: . .lua/bin/activate"
