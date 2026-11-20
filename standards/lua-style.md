# Lua style

## Lua 5.1 limits

WoW runs Lua 5.1, so newer Lua features do not exist:

- No `goto`, no integer division `//`, no bitwise operators. Use the built-in `bit` library (`bit.band`, `bit.bor`).
- No `table.unpack`: use `unpack`. No `table.pack`: use `{...}` with `select("#", ...)`.
- No `utf8` library.
- `os` and `io` are mostly removed. There is no file or network access. Saved variables are the only persistence.
- `require` and `module` do not exist. Files share code through the addon namespace (`local addonName, ns = ...`).

## WoW additions worth using

- `strsplit`, `strjoin`, `strtrim`, `wipe(t)`, `tinsert`, `tremove`, `Mixin`, `CreateFromMixins`.
- `C_Timer.After(seconds, fn)` and `C_Timer.NewTicker(seconds, fn)` instead of `OnUpdate` timing.
- `hooksecurefunc` to run code after a Blizzard function (see [combat-and-taint.md](combat-and-taint.md)).

## Conventions

- `local` by default, for every variable and function.
- Indent with 2 spaces or tabs, and use the same one throughout the project.
- Module tables in `PascalCase`, functions and variables in `camelCase`, constants in `UPPER_SNAKE_CASE`.
- One responsibility per file. Keep game logic in pure functions that take data and return data, apart from the code that calls the WoW API. Pure functions can be unit tested outside the game (see [../testing-debugging/offline-testing.md](../testing-debugging/offline-testing.md)).
- Check API results for `nil`. Many API functions return `nil` while data is still loading (item info, for example, before `GET_ITEM_INFO_RECEIVED`).
- Use `C_*` namespaced APIs (`C_Container`, `C_Item`, `C_AddOns`) over old global functions where both exist.
- Never trust input from chat, addon messages or other players. Validate before using it.
