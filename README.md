# GUA (Get Up Already)

A World of Warcraft: Forever addon.

## Layout

| Path | Contents |
|---|---|
| `gua.toc` | Addon manifest. Files load in the order listed. |
| `Locale.lua` | Translation table `ns.L` |
| `Logic.lua` | Pure functions, unit tested in `spec/` |
| `Core.lua` | Saved variables, defaults, migrations, events, print helpers |
| `Commands.lua` | `/gua` slash commands |
| `spec/` | busted unit tests |
| `scripts/` | Dev setup and game linking |
| `.claude/standards/` | Coding standards |
| `.claude/testing-debugging/` | How to test and debug |

## Getting started

```sh
scripts/setup-dev.sh     # once: Lua 5.1, luacheck, busted in ./.lua
. .lua/bin/activate      # each new terminal
scripts/link.sh          # once: symlink into the game's AddOns folder
```

If the game isn't in `/Applications/World of Warcraft`, run `WOW_DIR="/path/to/_forever_" scripts/link.sh`.

## Dev loop

```sh
luacheck .
busted
```

Then `/reload` in-game. In-game commands: `/gua help`, `/gua toggle`, `/gua debug`, `/gua version`.
