# Combat lockdown and taint

## Protected functions

Blizzard protects actions that could automate play: casting, targeting, moving, and changing secure frames (action buttons, unit frames). Addons can trigger these only through a direct player click on a secure button.

- **Combat lockdown:** During combat, addons cannot show, hide, move or resize protected frames, or change their attributes. Check with `InCombatLockdown()`.
- Queue such changes and apply them when `PLAYER_REGEN_ENABLED` fires (combat ends).
- To give a button a spell or macro, use a secure template (`SecureActionButtonTemplate`) and set its attributes outside combat.

## Taint

Code from addons is "tainted". If tainted code changes a variable or function that Blizzard's secure code later uses, that secure code is blocked. The player sees "Interface action failed because of an AddOn" or a disabled button.

To avoid taint:

- Never replace Blizzard functions or globals. Use `hooksecurefunc("FunctionName", fn)` or `hooksecurefunc(table, "method", fn)`, which runs your code after the original without tainting it.
- Use `frame:HookScript("OnShow", fn)` instead of `SetScript` on Blizzard frames.
- Don't write to Blizzard tables or frame fields.
- Don't call `UIDropDownMenu` functions or edit Blizzard dropdown menus from addon code, a common source of spreading taint.

Find the cause of taint with the taint log (see [../testing-debugging/in-game-tools.md](../testing-debugging/in-game-tools.md)).

## Secret values (Unverified for Forever)

Midnight introduced "secret values": during combat, some API results (for example health or aura details) are returned in a form addons cannot read or compare. Forever is built on Midnight-era code and may have the same rule. Check the Warcraft Wiki Forever page, section "Secrets", before building combat features.
