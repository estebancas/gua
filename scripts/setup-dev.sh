#!/bin/sh
# Installs Lua 5.1, luacheck, busted and luacov into ./.lua (project-local).
# CI runs this same script, so local runs and CI use the same versions.
# Afterwards run: . .lua/bin/activate
set -eu
cd "$(dirname "$0")/.."

# Python from python.org on macOS ships without CA certificates, which breaks
# hererocks downloads. Fall back to the system bundle when none is set.
if [ -z "${SSL_CERT_FILE:-}" ] && [ -f /etc/ssl/cert.pem ]; then
  export SSL_CERT_FILE=/etc/ssl/cert.pem
fi

python3 -m pip install --user hererocks==0.25.1
python3 -m hererocks .lua -l 5.1 -r 3.8.0

.lua/bin/luarocks install luacheck 1.2.0-1
.lua/bin/luarocks install busted 2.3.0-1
.lua/bin/luarocks install luacov 0.17.0-1

echo "Done. Run: . .lua/bin/activate"
