# In-game tools

## Built-in commands

| Command | Use |
|---|---|
| `/reload` | Reloads the UI and all addon Lua. Also saves saved variables. |
| `/console scriptErrors 1` | Shows Lua errors in a popup. Off by default. |
| `/dump <expression>` | Prints any value, including tables. Example: `/dump MyAddonDB` |
| `/run <lua>` | Runs a line of Lua. Example: `/run print(GetTime())` |
| `/fstack` | Shows the frames under the mouse, with names and layers. |
| `/etrace` | Opens the event trace window, a live list of events as they fire, with arguments. |
| `/tinspect <expression>` | Opens a table inspector. |
| `/api <search>` | Searches the built-in API documentation (modern clients). |
| `/console taintLog 1` | Writes taint information to `Logs/taint.log`. Use `2` for more detail. Turn it off afterwards, since it slows the game. |

## Debug addons

| Addon | Use |
|---|---|
| **BugGrabber** | Captures every Lua error, including ones during loading, and stops the default popup. |
| **BugSack** | Displays the errors BugGrabber collected, with full stack traces and local values. Install both. |
| **DevTool** | Inspects tables, frames, events and function calls at runtime. Send a value to it with `DevTool:AddData(value, "label")`. |

Check that each one has a version for Forever before installing.

## Debug logging in your addon

- Add a debug flag in saved variables, toggled by a slash command, and a logger that only prints when it is on:

  ```lua
  function ns.Debug(...)
    if MyAddonDB and MyAddonDB.debug then
      print("|cff33ff99MyAddon|r", ...)
    end
  end
  ```
- Remove noisy debug prints from hot paths before release, even when disabled: building the arguments still costs time.
- Wrap risky code in `xpcall(fn, geterrorhandler())` to report errors without stopping the rest of the addon.

## Reading an error

- BugSack shows the file and line, the call stack and the local variables at each level.
- "attempt to index a nil value" usually means an API returned `nil` because data was not loaded yet, or saved variables were read before `ADDON_LOADED`.
- "Interface action failed because of an AddOn" or "AddOn tried to call protected function" is taint. See [../standards/combat-and-taint.md](../standards/combat-and-taint.md) and check the taint log.

## Sources

- [BugSack](https://www.curseforge.com/wow/addons/bugsack)
- [DevTool (GitHub)](https://github.com/brittyazel/DevTool)
- [Warcraft Wiki: DevTools](https://warcraft.wiki.gg/wiki/DevTools)
