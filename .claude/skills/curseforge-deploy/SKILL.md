---
name: curseforge-deploy
description: Release the GUA addon to CurseForge. Use when asked to deploy, publish, release, upload or ship the addon, cut a new version, or set up CurseForge publishing.
---

# Deploy to CurseForge

Releases are built and uploaded by the **BigWigs packager** (`BigWigsMods/packager`). It reads `.pkgmeta`, pulls libraries, replaces `@project-version@` with the git tag, zips the addon and uploads it to CurseForge.

Publishing is public and can't be fully undone. **Always get the user's explicit go-ahead before pushing a tag or uploading.** Show them the version and changelog first.

Facts below were compiled 19 November 2026. Items marked **Unverified** come from third-party guides or conflict between sources.

## One-time setup

Check each item; tell the user what's missing. Steps marked (user) must be done by them in a browser.

1. **CurseForge project** (user): at https://authors.curseforge.com, *Create Project* → Game: World of Warcraft, Category: Addons, name and summary. Approval reportedly takes about a day.
2. **Project ID**: the number in the project's "About Project" sidebar (not the URL slug). Add it to `gua.toc`:
   ```toc
   ## X-Curse-Project-ID: 123456
   ```
3. **API token** (user): create one at https://www.curseforge.com/account/api-tokens. Never commit it or paste it in chat.
4. **Git + GitHub**: the folder must be a git repo pushed to GitHub for the Action route.
5. **GitHub secret** (user): repo Settings → Secrets and variables → Actions → New secret, named `CF_API_KEY`.
6. **Workflow permissions** (user): repo Settings → Actions → General → Workflow permissions → *Read and write*.
7. **Workflow file** `.github/workflows/release.yml`:
   ```yaml
   name: Release
   on:
     push:
       tags: ["v*"]
   jobs:
     release:
       runs-on: ubuntu-latest
       env:
         CF_API_KEY: ${{ secrets.CF_API_KEY }}
         CF_API_TOKEN: ${{ secrets.CF_API_KEY }}
         GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
       steps:
         - uses: actions/checkout@v4
           with:
             fetch-depth: 0
         - uses: BigWigsMods/packager@v2
   ```
   **Unverified:** the packager README names the token `CF_API_TOKEN`, while guides use `CF_API_KEY`. The workflow sets both from one secret until this is confirmed.

## Release steps

1. **Preflight** (stop on any failure):
   - `luacheck .` and `busted` pass (activate `.lua/bin/activate` first).
   - `## Interface` in `gua.toc` matches the current client. The user can check in-game with `/dump select(4, GetBuildInfo())`. 16001 = patch 1.60.1.
   - Working tree is clean and on the main branch.
   - Run through `.claude/testing-debugging/checklist.md` with the user, or confirm they have.
2. **Pick the version** with the user, using semantic versioning. The tag name sets the CurseForge release type (**Unverified**, from a third-party guide):
   | Tag | Type |
   |---|---|
   | `v1.2.0` | Release |
   | `v1.2.0-beta.1` | Beta |
   | `v1.2.0-alpha.1` | Alpha |
3. **Changelog**: summarize commits since the last tag (`git log $(git describe --tags --abbrev=0)..HEAD --oneline`) and add them to `CHANGELOG.md`. Commit it.
4. **Confirm** version and changelog with the user.
5. **Tag and push**: `git tag v1.2.0 && git push origin v1.2.0`. The Action builds and uploads.
6. **Verify** with the user on the CurseForge project's Files tab:
   - The file is there with the right release type.
   - **Game version is 1.60.1 (Forever).** The packager added Forever support in Sept 2026 (matching 1.6x interfaces), but one report says unknown interfaces get tagged as Retail. If it's wrong, the user fixes it on the file page.
   - The zip contains only addon files (no `spec/`, `.claude/`, scripts).

## Local build (no upload)

Useful to inspect the package before the first real release:

```sh
curl -sO https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh
bash release.sh -d        # -d = skip upload; output goes to .release/
```

Check `.release/` for the zip and its contents. Local uploads read tokens from a `.env` file, which is git-ignored; prefer the GitHub Action instead.

## Sources

- [BigWigsMods/packager](https://github.com/BigWigsMods/packager)
- [packager PR #202: Add WoW Forever support](https://github.com/BigWigsMods/packager/pull/202)
- [CurseForge author API docs](https://authors.curseforge.com/docs/api/529-api)
- [WoW addon template: publishing guide](https://wow-midnight-addon-template.vercel.app/publishing/)
