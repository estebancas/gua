# Tooling

## Linting

- **luacheck** catches undefined globals, unused variables and shadowing. Use a `.luacheckrc` such as:

  ```lua
  std = "lua51"
  max_line_length = false
  exclude_files = { "Libs/" }
  globals = { "MyAddonDB", "SLASH_MYADDON1", "SlashCmdList" }
  read_globals = { "CreateFrame", "C_Timer", "GetTime" } -- extend as needed
  ```
- Run it before every in-game test. It finds most typos faster than `/reload`.

## Version control

- Keep the source in a git repo outside the game folder, and symlink it into `AddOns/` (see [../testing-debugging/dev-workflow.md](../testing-debugging/dev-workflow.md)).
- Tag releases with semantic versions (`v1.2.0`). The packager uses the tag as the version.

## Packaging and publishing

- **BigWigs packager** (GitHub Action `BigWigsMods/packager`) reads `.pkgmeta`, pulls library externals, replaces `@project-version@`, zips the addon and uploads it to CurseForge and Wago.
- Publish on **CurseForge** and **Wago**, the two places players look for Forever addons.

## Sources

- [BigWigsMods/packager](https://github.com/BigWigsMods/packager)
