# The Forever platform

## Facts

- **Game:** World of Warcraft: Forever. Beta started 17 September 2026, launched 4 November 2026. Client version 1.60.x.
- **Language:** Lua 5.1 (the game's embedded interpreter), plus optional XML for frame layout. Nothing else runs: no compiled code, no other languages.
- **API:** The modern Mainline (Retail) UI engine and API, reportedly from the 12.1.5 (Midnight) era. It is **not** the Classic API.
  - Classic-era addons do not load and must be rebuilt.
  - Midnight/Retail addons usually port over with small changes.
  - Use Retail API documentation, not Classic documentation.
- **TOC Interface number:** `16001` for patch 1.60.1. It changes with each patch.
- **AddOns folder (macOS):** `/Applications/World of Warcraft/_forever_/Interface/AddOns/`

## Check before relying on

- **Interface number:** Run `/dump select(4, GetBuildInfo())` in-game. The fourth return value is the current TOC number. Update the `.toc` after every patch.
- **Unverified, secret values:** Forever is built on Midnight-era code, so it may share Midnight's combat restrictions, where addons get "secret" (unreadable) values for some combat data. The Warcraft Wiki Forever page has a "Secrets" section that was not reviewed. Read it before designing any feature that reads combat data.
- **Unverified, addon profiler:** Modern Retail clients include an addon CPU profiler (`C_AddOnProfiler`). Check whether it exists in Forever with `/dump C_AddOnProfiler`.

## Sources

- [Warcraft Wiki: World of Warcraft: Forever](https://warcraft.wiki.gg/wiki/Patch_1.60)
- [Warcraft Wiki: TOC format](https://warcraft.wiki.gg/wiki/TOC_format)
- [Gfinity: WoW Forever UI & Addons Setup Guide](https://www.gfinityesports.com/article/world-of-warcraft-forever-ui-addons-setup-guide)
- [CurseForge: migrate addons from Forever beta to live](https://blog.curseforge.com/wow-forever-migrate-addons-beta-to-live/)
- [Mobalytics: How to install addons in WoW Forever](https://mobalytics.gg/wow-forever/profile/broog/guides/how-to-install-addons-wow-forever)
