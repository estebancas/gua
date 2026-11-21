# Testing and CI guardrails: research report

Researched 2026-11-20. This report covers how to give an AI agent more freedom in this repo while automated checks judge its output. It also covers how to stop security risks from reaching the repo or the CurseForge zip.

## 1. Summary

- **No top addon has a full guardrail setup.** Each one does part of it. Together they show which parts matter: Questie runs unit tests, WeakAuras pins actions and runs security regression tests, and DBM builds a test package on every PR.
- **GUA already has the right base.** It has luacheck, busted, and `Logic.lua` kept pure. Nothing runs these yet. There is no `.github/`, and nothing checks what the release zip contains.
- **One real problem now: `CLAUDE.md` and `PLAN.md` would ship in the release zip.** The BigWigs packager always drops files and folders whose names start with a dot (`release.sh` line 1851), so listing `.lua`, `.claude` and `.github` in `.pkgmeta` does nothing. `CLAUDE.md` and `PLAN.md` are not ignored. `README.md` also ships, which is usually fine.
- **GitHub plan limit:** the repo is private on a free plan. The GitHub API refuses to set up branch protection rules ("Upgrade to GitHub Pro or make this repository public"). GitHub's own secret scanning is also not available. Until the repo is public or the plan is upgraded, the checks must run in CI and in local hooks.

## 2. What the top addons do

The ranking uses CurseForge all-time downloads, read on 2026-11-20. These are the top 5 that have an active public GitHub repo. Auctionator, RareScanner and GTFO rank high but have no public repo. BigWigs ranks 7th and is included because it makes the packager everyone uses.

| Addon (downloads) | Lint | Types (LuaLS) | Unit tests | Package test on PR | Actions pinned to commit SHA | Dependabot | Other |
|---|---|---|---|---|---|---|---|
| **DBM** (644M) | luacheck, but global-variable checks turned off | Yes, blocking (`DeadlyBossMods/LuaLS-config`) | No | Yes: `packager -d`; zip uploaded and linked in a PR comment | No (`@main`, `@master`) | No | Discord alert on failure |
| **Raider.IO** (458M) | No | No | Lua scripts in `tests/`, not run in CI | No | No (`checkout@v1`) | No | Release on tag only, uses a GitHub `environment` |
| **Details!** (377M) | No | No | No | No | No | No | Releases on every push to master, with secrets set at the workflow level |
| **WeakAuras** (256M) | luacheck with PR annotations | `.luarc.json` for editors only | **Sandbox escape regression tests** (`tests/`, Lua 5.1) | Yes: `packager -d` | **Yes, all of them** | Yes (actions) | Only collaborators can download the PR build; `permissions: contents: read`; `persist-credentials: false`; `AGENTS.md`/`CLAUDE.md` |
| **Questie** (228M, ships `Questie_Forever.toc`) | luacheck | `.luarc.json` and `.types/` for editors | **busted with WoW mocks** (`setupTests.lua`, `*.test.lua`), using pinned rock versions | No | No (version tags) | Yes (actions) | Custom structure check (`cli/validate-loader-usage.lua`); Python tests for build scripts; release checks in `validate-bundle.sh`; per-job `permissions`; `AGENTS.md` |
| *BigWigs* (210M) | luacheck | No | No | No | No (`@main`) | No | Custom lint for boss modules |

Takeaways:

1. **Questie is the model for tests.** It loads real addon files in busted with fake WoW globals, the same approach as our `spec/helpers.lua`. It pins `busted 2.2.0-1` and sets up Lua 5.1 with `leafo/gh-actions-lua` plus `leafo/gh-actions-luarocks`. None of these addons emulates the game client.
2. **WeakAuras is the model for security.** Every action is pinned to a commit SHA, Dependabot updates them, and permissions are minimal. The sandbox tests check that escape routes that were found and closed stay closed. Their README says it plainly: "A passing run is not a security proof."
3. **DBM is the model for checking the package.** Every PR builds the real zip with `packager -d`, which skips the upload step.
4. **DBM is also the model for type checking.** It runs Lua Language Server (LuaLS) `--check` as a blocking CI step. DBM turned off luacheck's global-variable checks because LuaLS catches undefined API calls better.
5. **Two of the top five agent-assisted repos (WeakAuras, Questie) commit an `AGENTS.md`** listing the exact commands to run before finishing. That matches our `CLAUDE.md`.
6. **Common weak spots:** unpinned `@main` actions (DBM, BigWigs), release secrets available to every job (Details!, Raider.IO), and releases on every push to master. Avoid all three.

## 3. Recommended guardrails for GUA

Ordered by how much each helps compared with its cost. Items 1–6 make up the "agent judge": each one fails with a clear message the agent can act on.

### Tier 1: the CI that evaluates code (`.github/workflows/ci.yml`, runs on push and PR)

1. **luacheck** (`luacheck .`). Keep the hand-written `read_globals` list. It is stricter than DBM's setup and catches API names an agent made up: an unknown global fails the build. Install it the same way as `scripts/setup-dev.sh` (hererocks), so local runs and CI behave the same.
2. **busted plus a coverage minimum.** Run `busted --coverage` and `luacov` with a `.luacov` file that includes `Logic.lua` only. LuaCov has no built-in way to fail below a percentage, so a short script reads the `Total` line and fails under 90%. Without the minimum, an agent can add logic with no tests.
3. **Forbidden-API check** (a small grep script). No existing tool lints Lua for these risks: CodeQL does not support Lua, and Semgrep's Lua support is experimental. Fail the build on:
   - `loadstring`, `load(`, `RunScript`, `setfenv`/`getfenv`, which run text as code;
   - `SendAddonMessage`, `CHAT_MSG_ADDON`, `RegisterAddonMessagePrefix`, `SendChatMessage`, which talk to other players;
   - `EditMacro`, and `hooksecurefunc` on Blizzard frames.

   Allow a use only with an `-- gua-allow: <reason>` comment on the same line. GUA has no reason to talk to other players or run strings as code, so any of these is a red flag.
4. **TOC check** (a short Lua script):
   - `## Interface:` is present and numeric;
   - `## Version: @project-version@` is present;
   - every file listed exists;
   - every `*.lua` outside `spec/`, `scripts/` and `.lua/` is listed.

   An agent that adds a file and forgets the `.toc` fails here, not silently in the game.
5. **Package allowlist.** Run `BigWigsMods/packager` with `-d` and no secrets, then `unzip -l .release/*.zip`. Fail if any path is outside an allowlist (`gua/gua.toc`, `gua/*.lua` in the TOC, `gua/LICENSE`, `gua/README.md`). This would catch the `CLAUDE.md`/`PLAN.md` leak above and any stray file an agent creates.
6. **LuaLS type check, not blocking at first.** Run `lua-language-server --check . --checklevel=Warning` with [Ketho/vscode-wow-api](https://github.com/Ketho/vscode-wow-api) annotations pinned to a commit. Those annotations follow the Retail API, which is what Forever uses, but expect some false positives for Forever-only differences. Make it blocking once it runs clean. DBM's composite action (`DeadlyBossMods/LuaLS-config`) shows how to build and cache it.

### Tier 2: security of the repo and the pipeline (`.github/workflows/security.yml`, Dependabot)

7. **Pin every action to a full commit SHA**, with the version in a comment, as WeakAuras does. Add `.github/dependabot.yml` with `package-ecosystem: github-actions`, weekly.
8. **zizmor** (`zizmorcore/zizmor-action`). It lints the workflows themselves for unpinned actions, template injection, `pull_request_target`, too-broad permissions and kept credentials. Add **actionlint**, which also runs shellcheck on `run:` blocks.
9. **gitleaks**, in CI and as a pre-commit hook. GitHub's own secret scanning is not available on this private free repo, so this is the only secret check.
10. **Least privilege in every workflow:**
    - set `permissions: contents: read` at the top level;
    - set `persist-credentials: false` on checkout;
    - never use `pull_request_target`.
11. **A separate `release.yml`** that runs only on `v*` tags and only after CI passes. It is the only job that sees `CF_API_KEY`/`WAGO_API_TOKEN`. Store those in a `release` environment, and add required reviewers if the plan allows it. Unlike Details!, it never releases on a push to `main`.
12. **`.pkgmeta` externals:** there are none today. If a library is added, pin it to a `tag:`, because an external is third-party code inserted into the shipped zip at build time.

### Tier 3: local guardrails that check the agent before CI does

13. **Claude Code hooks** in `.claude/settings.json`:
    - a `PostToolUse` hook on `Edit|Write` runs `luacheck` on the changed `.lua` file;
    - a `Stop` hook runs `busted` and the forbidden-API check.

    Exit code 2 sends the error back to the agent, so it fixes its own mistakes within the same turn. CI stays the final check, because local hooks can be skipped.
14. **pre-commit** (optional): luacheck, gitleaks, and busted as a local hook.

### Tier 4: GitHub settings (need GitHub Pro or a public repo)

15. A **branch protection rule on `main`**: require a PR, require the CI and security checks, block force-push.
16. A **tag rule on `v*`**: only you can create tags, since a tag triggers a public release.
17. **CODEOWNERS** for `.github/`, `.pkgmeta`, `*.toc`, `.claude/settings.json`. This stops an agent's PR from weakening its own guardrails without your review.
18. **OpenSSF Scorecard**, once the repo is public.

Without the upgrade, items 15–17 cannot be enforced. CI still runs on every PR, but nothing blocks a merge, so you are the gate.

### Not recommended now

- **wowless** (headless client emulator): pre-alpha, Docker only, and it may break with Forever changes. Revisit if UI code grows.
- **StyLua**: useful, but it is about style, not safety, and it needs one large reformatting commit. Add it with `syntax = "Lua51"` if wanted.
- **Selene**: has no WoW standard library. luacheck plus LuaLS already cover what it would check.
- **Property-based testing in Lua:** no maintained library. Use table-driven busted cases instead.

## 4. Suggested order of work

1. ~~Fix the zip leak: add `CLAUDE.md`, `PLAN.md` and `guardrails-research.md` to `.pkgmeta` `ignore:`, and remove the dotfile entries, which do nothing.~~ Done.
2. Add `ci.yml` with items 1–5, plus `dependabot.yml`, everything pinned to SHAs.
3. Add `security.yml` with zizmor, actionlint and gitleaks.
4. Add the Claude Code hooks (item 13) and list the guardrails in `CLAUDE.md`.
5. Add LuaLS (item 6), non-blocking, then make it blocking.
6. Add `release.yml` when the first release is near; it fits with the `curseforge-deploy` skill.
7. Decide on GitHub Pro or making the repo public, then add the settings in Tier 4.

Tracked as GitHub issues labeled `guardrails`:

| Tier | Issue |
|---|---|
| 1: CI that evaluates code (items 1–5) | #40 |
| 1: LuaLS type check (item 6) | #41 |
| 2: security of workflows, secrets, dependencies (items 7–12) | #42; release parts also in #37 |
| 3: Claude Code hooks and local checks (items 13–14) | #43 |
| 4: GitHub rulesets and CODEOWNERS (items 15–18) | #44, blocked on the Pro/public decision |

Step 1 (the zip leak) is done. A local `packager -d` dry run now produces only `gua.toc`, the four `.lua` files, `README.md` and the generated `CHANGELOG.md`.

### Where each convention comes from

These links are pinned to the commit read on 2026-11-20, so they stay valid as those repos change.

| Convention | Reference file |
|---|---|
| Lua 5.1 + busted in CI, pinned rock versions | Questie [`.github/workflows/ci.yml`](https://github.com/Questie/Questie/blob/99bef7a7b721aefb4ba070029ef91d62e9108d61/.github/workflows/ci.yml) |
| Real addon files loaded with fake WoW globals | Questie [`setupTests.lua`](https://github.com/Questie/Questie/blob/99bef7a7b721aefb4ba070029ef91d62e9108d61/setupTests.lua) |
| Custom structure check as a CI step | Questie [`cli/validate-loader-usage.lua`](https://github.com/Questie/Questie/blob/99bef7a7b721aefb4ba070029ef91d62e9108d61/cli/validate-loader-usage.lua) |
| Release validated before upload | Questie [`validate-bundle.sh`](https://github.com/Questie/Questie/blob/99bef7a7b721aefb4ba070029ef91d62e9108d61/validate-bundle.sh) |
| Per-job `permissions` | Questie [`.github/workflows/publish.yml`](https://github.com/Questie/Questie/blob/99bef7a7b721aefb4ba070029ef91d62e9108d61/.github/workflows/publish.yml) |
| Agent instructions file with exact commands | Questie [`AGENTS.md`](https://github.com/Questie/Questie/blob/99bef7a7b721aefb4ba070029ef91d62e9108d61/AGENTS.md), WeakAuras [`AGENTS.md`](https://github.com/WeakAuras/WeakAuras2/blob/5499776eb4a78ddb4d896fc9a75c3835a77565ed/AGENTS.md) |
| Actions pinned to SHAs, `contents: read`, `persist-credentials: false` | WeakAuras [`pull_request.yml`](https://github.com/WeakAuras/WeakAuras2/blob/5499776eb4a78ddb4d896fc9a75c3835a77565ed/.github/workflows/pull_request.yml), [`build.yml`](https://github.com/WeakAuras/WeakAuras2/blob/5499776eb4a78ddb4d896fc9a75c3835a77565ed/.github/workflows/build.yml) |
| Dependabot for actions | WeakAuras [`dependabot.yml`](https://github.com/WeakAuras/WeakAuras2/blob/5499776eb4a78ddb4d896fc9a75c3835a77565ed/.github/dependabot.yml), Questie [`dependabot.yml`](https://github.com/Questie/Questie/blob/99bef7a7b721aefb4ba070029ef91d62e9108d61/.github/dependabot.yml) |
| Security regression tests, and their limits | WeakAuras [`tests/README.md`](https://github.com/WeakAuras/WeakAuras2/blob/5499776eb4a78ddb4d896fc9a75c3835a77565ed/tests/README.md) |
| `packager -d` test zip on every PR | DBM [`.github/workflows/ci.yml`](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/bbb478ac3373a8a5c75ab30c0658c5ee25232042/.github/workflows/ci.yml) |
| LuaLS check in CI | DBM [`ci.yml`](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/bbb478ac3373a8a5c75ab30c0658c5ee25232042/.github/workflows/ci.yml), [`LuaLS-config/action.yml`](https://github.com/DeadlyBossMods/LuaLS-config/blob/fff2244b2bc47780f702713edf833487bc37cb30/action.yml), [`.luarc.json`](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/bbb478ac3373a8a5c75ab30c0658c5ee25232042/.luarc.json) |
| Release secrets in a GitHub environment | Raider.IO [`release.yml`](https://github.com/RaiderIO/raiderio-addon/blob/HEAD/.github/workflows/release.yml) |
| The packager skips dotfiles | BigWigs packager [`release.sh#L1851`](https://github.com/BigWigsMods/packager/blob/01e8631a69c69d7654c788d152630d5fed9e3812/release.sh#L1851) |
| Anti-example: secrets for the whole workflow, release on every push | Details! [`release.yml`](https://github.com/Tercioo/Details-Damage-Meter/blob/HEAD/.github/workflows/release.yml) |

## 5. Unverified or open

- How many false positives LuaLS with the Ketho annotations gives on Forever. Measure it on GUA.
- Whether GitHub Pro covers required reviewers on environments for private repos.
- Ranking confidence is medium: CurseForge ignores the sort-by-downloads URL parameter, so the order was built from the download counts shown in the top 50 results.

## Sources

- Addon repos: [DeadlyBossMods/DeadlyBossMods](https://github.com/DeadlyBossMods/DeadlyBossMods), [RaiderIO/raiderio-addon](https://github.com/RaiderIO/raiderio-addon), [Tercioo/Details-Damage-Meter](https://github.com/Tercioo/Details-Damage-Meter), [WeakAuras/WeakAuras2](https://github.com/WeakAuras/WeakAuras2), [Questie/Questie](https://github.com/Questie/Questie), [BigWigsMods/BigWigs](https://github.com/BigWigsMods/BigWigs). In each one, read `.github/workflows/`.
- Lua testing: [lunarmodules/busted](https://github.com/lunarmodules/busted), [lunarmodules/luacov](https://github.com/lunarmodules/luacov).
- Lint and types: [lunarmodules/luacheck](https://github.com/lunarmodules/luacheck), [LuaLS/lua-language-server](https://github.com/LuaLS/lua-language-server), [Ketho/vscode-wow-api](https://github.com/Ketho/vscode-wow-api), [DeadlyBossMods/LuaLS-config](https://github.com/DeadlyBossMods/LuaLS-config).
- Lua in GitHub Actions: [leafo/gh-actions-lua](https://github.com/leafo/gh-actions-lua), [leafo/gh-actions-luarocks](https://github.com/leafo/gh-actions-luarocks).
- Packaging: [BigWigsMods/packager](https://github.com/BigWigsMods/packager) (`release.sh`, which drops dotfiles).
- Security tools: [zizmorcore/zizmor](https://github.com/zizmorcore/zizmor), [rhysd/actionlint](https://github.com/rhysd/actionlint), [gitleaks/gitleaks-action](https://github.com/gitleaks/gitleaks-action), [ossf/scorecard-action](https://github.com/ossf/scorecard-action).
- Client emulation: [wowless/wowless](https://github.com/wowless/wowless).
- Language support: [CodeQL supported languages](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/), [Semgrep supported languages](https://docs.semgrep.dev/supported-languages).
- GitHub docs: [About secret scanning](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning), [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).
