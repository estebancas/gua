# Development workflow

## One-time setup

1. Keep each addon's source in its own folder, for example `~/Projects/Personal/wow/gua/`.
2. Symlink it into the game so edits apply without copying. For GUA, run `scripts/link.sh`, which links the folder as `AddOns/gua`. By hand:

   ```sh
   ln -s ~/Projects/Personal/wow/gua "/Applications/World of Warcraft/_forever_/Interface/AddOns/gua"
   ```
   The link name must match the `.toc` file name (`gua` ↔ `gua.toc`).
3. Install the debug addons from [in-game-tools.md](in-game-tools.md): BugGrabber, BugSack and DevTool.
4. In-game, run `/console scriptErrors 1` once so Lua errors are shown.
5. Use a test character, ideally on a separate account or the beta/PTR (test realm), so broken saved variables don't affect your main.

## The loop

1. Edit the code.
2. Run `luacheck .` (see [offline-testing.md](offline-testing.md)).
3. Run the unit tests with `busted`.
4. In-game, type `/reload`.
5. Check BugSack for errors and test the feature.

## What needs a restart instead of `/reload`

- Changes to the `.toc` file.
- New files, including new images or sounds.
- A new addon folder.

Lua and XML edits to files already listed in the `.toc` only need `/reload`.

## Useful paths (macOS)

| Path | Contents |
|---|---|
| `_forever_/Interface/AddOns/` | Installed addons |
| `_forever_/WTF/Account/<ACCOUNT>/SavedVariables/MyAddon.lua` | Account-wide saved variables, readable Lua |
| `_forever_/WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/` | Per-character saved variables |
| `_forever_/Logs/` | Taint log and other client logs |

All paths are relative to `/Applications/World of Warcraft/`.

Saved variables are written on `/reload`, logout or exit. Read the files to check what your addon stored. Delete the file, with the game closed, to test a first install.
