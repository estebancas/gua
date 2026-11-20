# Testing outside the game

Much of an addon can be checked without starting WoW. This is faster than `/reload` and can run in CI.

## Setup on macOS

The tests should run on Lua 5.1, the same version as WoW. Homebrew no longer ships Lua 5.1, so install it in a project-local environment with `hererocks`:

```sh
pip install hererocks
hererocks .lua -l 5.1 -r latest      # Lua 5.1 + LuaRocks in ./.lua
source .lua/bin/activate
luarocks install luacheck
luarocks install busted
```

Add `.lua/` to `.gitignore`.

## Linting with luacheck

```sh
luacheck .
```

Configure it with `.luacheckrc` (example in [../standards/tooling.md](../standards/tooling.md)). Treat every warning as something to fix or to allow explicitly.

## Unit tests with busted

Only pure logic can be tested this way: calculations, parsing, data handling. That is why the standards keep logic apart from WoW API calls.

```
MyAddon/
├── Logic.lua            # pure functions, no WoW API calls
└── spec/
    ├── wow_stubs.lua    # fake WoW API
    └── logic_spec.lua
```

Each addon file expects `addonName, ns` from `...`. Load it the same way in tests:

```lua
-- spec/logic_spec.lua
local function loadAddonFile(path, ns)
  local chunk = assert(loadfile(path))
  chunk("MyAddon", ns)
  return ns
end

describe("Logic", function()
  local ns

  before_each(function()
    ns = loadAddonFile("Logic.lua", {})
  end)

  it("formats rested percentage", function()
    assert.are.equal("50%", ns.Logic.formatPercent(0.5))
  end)
end)
```

For code that calls the WoW API, define fakes before loading the file:

```lua
-- spec/wow_stubs.lua
_G.GetTime = function() return 100 end
_G.UnitLevel = function() return 20 end
_G.C_Timer = { After = function(_, fn) fn() end }
```

Run:

```sh
busted
```

## Limits

- Frames, events, rendering and combat behaviour can't be tested outside the game. Fakes for `CreateFrame` quickly become as complex as the real thing. Test those parts in-game with [checklist.md](checklist.md).
- Fakes can drift from the real API. When a test passes but the game fails, check the fake against the real API with `/dump`.
