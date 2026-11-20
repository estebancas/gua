# Addon structure

## Folder layout

```
MyAddon/
├── MyAddon.toc        # must match the folder name exactly
├── Core.lua
├── Locales/           # optional: translations
├── Libs/              # embedded libraries (pulled by the packager, not committed)
└── .pkgmeta           # packager config
```

- The folder sits directly in `Interface/AddOns/`. A doubled folder like `AddOns/MyAddon/MyAddon/` does not load.
- The `.toc` file name must match the folder name.

## The `.toc` file

```toc
## Interface: 16001
## Title: MyAddon
## Notes: One line describing what it does.
## Author: <name>
## Version: @project-version@
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB

Libs\LibStub\LibStub.lua
Core.lua
```

- Files load in the order listed. List libraries first.
- Without a correct `## Interface` line the game marks the addon "out of date".
- `@project-version@` is replaced with the git tag by the packager.
- Changes to the `.toc` or new files need a full game restart, not just `/reload`.

## Namespaces and globals

- Every file receives the addon name and a private table shared by all files of the addon. Use it instead of globals:

  ```lua
  local addonName, ns = ...
  ns.Config = {}
  ```
- Only these should be global: saved variables, slash command entries, and frames that must be named. Prefix every global name with the addon name, for example `MyAddonDB` or `MyAddon_MainFrame`.

## Saved variables

- They are not available while files load. Read them in the `ADDON_LOADED` event for your own addon, or at `PLAYER_LOGIN`.
- Merge defaults into them so new settings appear for existing users:

  ```lua
  local defaults = { enabled = true, scale = 1 }

  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    MyAddonDB = MyAddonDB or {}
    for k, v in pairs(defaults) do
      if MyAddonDB[k] == nil then MyAddonDB[k] = v end
    end
    self:UnregisterEvent("ADDON_LOADED")
  end)
  ```
- They are written to disk only on `/reload`, logout or exit. A crash loses changes since the last save.
- Store a schema version number in them so later releases can migrate old data.

## Events

- Use one event frame per module that dispatches by event name:

  ```lua
  local f = CreateFrame("Frame")
  function f:PLAYER_LOGIN() end
  function f:PLAYER_REGEN_DISABLED() end
  f:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  ```
- Unregister events once they are no longer needed.

## Libraries

- **Ace3** is the standard framework: AceAddon (lifecycle), AceDB (saved variables with profiles), AceConfig (options screens), AceConsole (slash commands), AceEvent.
- **LibStub** loads library versions so that several addons can share one copy.
- Do not commit libraries. List them as `externals` in `.pkgmeta` so the packager pulls them at build time.
- Start without libraries for small addons. Add Ace3 once you need profiles or an options screen.

## Localization

- Keep every user-facing string in one locale table, with English as the fallback:

  ```lua
  local L = setmetatable({}, { __index = function(t, k) return k end })
  ns.L = L
  ```
