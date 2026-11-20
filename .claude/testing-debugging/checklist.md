# Release checklist

## Offline

- [ ] `luacheck .` has no warnings.
- [ ] `busted` passes.
- [ ] `## Interface` in the `.toc` matches `/dump select(4, GetBuildInfo())`.
- [ ] Every file the addon uses is listed in the `.toc`.

## In-game

- [ ] **Clean install:** Delete the saved variables file (game closed), log in, and check there are no errors and the defaults apply.
- [ ] **Upgrade:** Log in with saved variables from the previous release and check the data migrates.
- [ ] **Login and reload:** No errors in BugSack after login, `/reload`, and a zone change through a loading screen.
- [ ] **Combat:** Enter and leave combat. No "action blocked" messages, and changes queued during combat apply afterwards.
- [ ] **Group:** Test in a party and, if relevant, a raid or dungeon.
- [ ] **Alone:** The addon is the only one enabled, so it doesn't depend on another addon by accident.
- [ ] **With other addons:** Popular addons enabled (for example a quest helper and unit frames), to catch conflicts.
- [ ] **Other characters:** A low-level character and a different class, if the addon depends on level or class.
- [ ] **Performance:** Memory is stable after 10 minutes of play (see [profiling.md](profiling.md)).
- [ ] **Taint:** If any message appeared, check `Logs/taint.log` with `/console taintLog 1`.

## Package

- [ ] Git tag created with the new version.
- [ ] The packaged zip installs and loads from a clean `AddOns/` folder.
