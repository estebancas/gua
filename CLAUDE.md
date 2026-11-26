# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

GUA (Get Up Already) is a World of Warcraft: **Forever** addon that reminds the player to take breaks at moments that cost nothing in game, and uses those breaks to build Rested XP. The code is currently a scaffold; product decisions live in `PLAN.md`.

## Commands

```sh
scripts/setup-dev.sh            # once: Lua 5.1 + luacheck + busted + luacov into ./.lua (via hererocks;
                                # every rock, dependencies included, pinned to an exact version)
. .lua/bin/activate             # each new shell, before luacheck/busted
scripts/link.sh                 # once: symlink repo into the game's AddOns/ as "gua"
                                # (override with WOW_DIR="/path/to/_forever_")

luacheck .                      # lint
busted                          # all tests (run from repo root; specs use relative paths)
busted spec/logic_spec.lua      # one spec file
busted --filter "parseCommand"  # tests whose name matches

# The CI checks (.github/workflows/ci.yml). Run them all before finishing work:
sh scripts/check-all.sh         # luacheck, tests + coverage, forbidden APIs, TOC; reports every failure
sh scripts/test.sh              # tests + coverage only (clears old coverage data first)
```

CI also builds the zip with the BigWigs packager (`-d`, no upload) and runs `scripts/check-package.sh`. It fails when a file listed in `gua.toc` is missing from the zip, or when the zip holds anything besides `gua.toc`, the files it lists, `README.md`, `CHANGELOG.md`, `LICENSE` or `LICENSE.md`.

- **Coverage:** `Logic.lua` must stay at 90% or more; new logic needs specs. Run tests through `scripts/test.sh`: plain `busted --coverage` adds to old coverage data, so a deleted test can still look covered.
- **Forbidden APIs:** fail the build unless a comment ending the line says `-- gua-allow: <reason>`. Adding one makes the PR risky. The list:
  - code from strings: `loadstring`, `load`, `RunScript`, `setfenv`/`getfenv`;
  - global lookup by a computed name: `_G[...]`, `getglobal`, `rawget(_G, ...)`;
  - addon and chat messaging;
  - macro edits;
  - `hooksecurefunc`.

  It scans every file `gua.toc` lists, whatever its folder. It ignores comments. It catches mistakes, not a call hidden on purpose (a name built at run time can still get past it), so review still matters.
- **TOC:** every addon `.lua` file must be listed in `gua.toc` with the exact case, and no listed file may be in a folder `.pkgmeta` ignores. Only `spec/`, `scripts/`, `.lua/` and libraries declared under `externals:` in `.pkgmeta` are exempt; a folder name like `Libs/` is not.
- Never weaken a check (thresholds, allowlists, `.luacheckrc` ignores) to make it pass. Fix the code, or say so in the PR so the owner reviews it.

In-game: `/reload` picks up Lua edits. Changes to `gua.toc` or adding new files need a full game restart. Slash commands: `/gua help|toggle|debug|version`.

## Architecture

- **Load order is the `gua.toc` file list**: `Locale.lua` → `Logic.lua` → `Core.lua` → `Commands.lua`. Each file receives `local addonName, ns = ...` and shares code only through `ns` (no `require` in WoW). A file may only use `ns.*` set by files earlier in the list. New files must be added to the `.toc`.
- **`Logic.lua` is pure**: no WoW API calls, so it can be loaded by busted. `spec/helpers.lua` `loadAddonFile(path, ns)` loads a file the way WoW does (passing `"gua", ns`). Put any testable logic here and keep WoW API calls in the other files.
- **`Core.lua`** owns saved variables and events:
  - `GUADB` (account-wide) is initialized in `ADDON_LOADED`: `Logic.mergeDefaults(GUADB, DEFAULTS)` then `migrate()`, then exposed as `ns.db`. `ns.db` is nil before then.
  - When the saved data shape changes, bump `DB_VERSION` and add a step to `migrate()`.
  - Events dispatch by name: define `function events:EVENT_NAME(...)` on `ns.events` and `RegisterEvent` it.
  - Output goes through `ns.Print` / `ns.Debug` (debug only prints when `ns.db.debug`).
- **`Commands.lua`**: `/gua` subcommands are entries in a local `commands` table; unknown input falls back to `help`.
- **`Locale.lua`**: `ns.L["English text"]` — English strings are the keys and a missing key returns itself. Wrap all user-facing strings in `L[...]`.

## Platform constraints

- Lua 5.1 only (no `goto`, `//`, bitwise ops, `table.unpack`, `utf8`, `require`, file/network IO). Use WoW helpers (`C_Timer`, `strsplit`, `wipe`, `bit.*`) and prefer `C_*` namespaced APIs.
- Forever uses the **modern Retail (Midnight-era) API, not Classic** — consult Retail docs. `## Interface: 16001` must be updated each patch (`/dump select(4, GetBuildInfo())`).
- `.luacheckrc` whitelists globals: add every new WoW API name to `read_globals`, and every global the addon creates to `globals` (prefix them with `GUA`).

## Standards and testing docs

Read the relevant file before working in that area. They hold the detail this file only summarizes.

`.claude/standards/`: how to write addon code for Forever.

| File | Read before |
|---|---|
| `forever-platform.md` | Relying on any client fact: API flavor, TOC number, folders, unverified items (secret values, `C_AddOnProfiler`) |
| `addon-structure.md` | Adding files, globals, saved variables, events, libraries or localization |
| `lua-style.md` | Writing Lua: 5.1 limits, WoW helpers, naming and file conventions |
| `performance.md` | Adding `OnUpdate`, frequent events, timers or anything running often |
| `combat-and-taint.md` | Touching protected functions, secure buttons, Blizzard frames or anything active in combat |
| `tooling.md` | Changing lint config, packaging or publishing |

`.claude/testing-debugging/`: how to verify changes.

| File | Read before |
|---|---|
| `dev-workflow.md` | Setting up the symlink, the edit → luacheck → busted → `/reload` loop, saved-variable file paths |
| `offline-testing.md` | Writing busted specs or stubbing WoW API for tests |
| `in-game-tools.md` | Debugging in game: `/dump`, BugSack, DevTool, error and taint logs |
| `profiling.md` | Measuring CPU or memory use |
| `checklist.md` | Preparing a release |

## Planning and research

- `PLAN.md` records numbered product decisions (D1…). Update it when a decision changes rather than diverging in code.
- Decisions tagged **[Research: R#]** depend on open questions tracked as GitHub issues labeled `research` (table at the end of `PLAN.md`). Resolve the research item before building a flagged decision.
- `rested-xp.md` holds the Rested XP game-mechanics research.

## Branches

Name branches `<type>/<issue>-<short-description>`, for example `feat/12-flight-reminder`, `fix/27-popup-shows-in-combat`, `docs/31-readme-install-steps`.

- **Type:** a Conventional Commits word: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`. This keeps branch lists sorted by kind of work.
- **Issue number:** the GitHub issue the branch works on. Put `Fixes #<issue>` in the pull request so merging closes the issue and moves it to Done on the Kanban board.
- **Short description:** three or four kebab-case words, enough to recognise the branch without opening the issue.

## Releasing

Releases go through the BigWigs packager (`.pkgmeta`; `@project-version@` in the `.toc` is replaced by the git tag). Use the `curseforge-deploy` skill. Publishing is public — get explicit user approval before pushing a tag or uploading.
