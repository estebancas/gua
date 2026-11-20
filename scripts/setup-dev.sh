#!/bin/sh
# Installs Lua 5.1, luacheck and busted into ./.lua (project-local).
# Afterwards run: . .lua/bin/activate
set -eu
cd "$(dirname "$0")/.."

python3 -m pip install --user hererocks
python3 -m hererocks .lua -l 5.1 -r latest

.lua/bin/luarocks install luacheck
.lua/bin/luarocks install busted

echo "Done. Run: . .lua/bin/activate"
