# GUA (Get Up Already): Product Plan

Living record of decisions from the design interview. Each decision is final until changed here.

Started 19 November 2026.

## Vision

A WoW: Forever addon that reminds the player to stand up, stretch or take a short break, and picks the moments when stepping away costs nothing in game: flight paths, resting in an inn or capital, idle time out of combat. It also uses those breaks to grow Rested XP (see [rested-xp.md](rested-xp.md)).

## Context already known

- Code base is a scaffold: saved variables (`GUADB`), `/gua` commands (`toggle`, `debug`, `version`), pure `Logic.lua` tested with busted.
- Rested XP facts that matter for break design:
  - Time online in a rested zone (inn, capital) builds rested XP at the same rate as being logged out there.
  - Cozy Sleeping Bag (quest from level 14): +1% XP per minute rested inside it, up to +3%, ideal for ~3-minute breaks. It may also count as a rested zone (sources disagree).
  - Logging out in an inn, capital or sleeping bag gives full rested gain; elsewhere only a quarter.

## Decisions

### D1. Timing model: timer, then wait for a good moment

After a set amount of play time a break becomes **due**. The addon then waits for a good moment to remind the player.

- **Default interval: 60 minutes** of play, configurable.
- **Never forced** (see D5): the reminder appears only at a good moment, however long that takes. While a break is due but no good moment has come, a subtle "break due" indicator is shown instead.

### D2. Good break moments (all four) **[Research: R5]**

1. Flight paths (taxi): triggers after **20 seconds** in the air, to skip short hops (the game doesn't expose flight duration).
2. Resting in an inn or capital (rested zone): triggers when the player **stops there**, out of combat and not moving for 15 seconds, so running through a city doesn't fire it.
3. Idle out of combat: no movement or action for **2 minutes** (default, configurable).
4. Queues and dead time: dungeon queue, ghost run, long loading screens, boat and zeppelin rides.

Each moment type has its own on/off checkbox in settings; **all on by default**.

### D3. Reminder style: configurable, defaults are popup + sound **[Research: R10, R11]**

- Defaults: a **small dismissable popup** and a **sound**.
- Every alert channel can be switched on or off by the user. Other channels to offer as options: center-screen banner, flashing the dock/taskbar icon.
- **Sound:** a dropdown of 4 or 5 built-in game sounds, a gentle chime by default. Plays even when the game is in the background.

### D4. Rested XP features (three in v1) **[Research: R1, R2, R8]**

1. **Sleeping bag prompt:** when a break starts outside a rested zone, remind the player to place the Cozy Sleeping Bag so the break also earns the +3% XP buff.
   - The addon must detect whether the character **owns** the sleeping bag and only suggest it if they do.
2. **Rested XP tracker:** show the current rested pool and how much each break earned.
3. **Smart logout advice:** when logging out, warn if the character is not in a rested zone or sleeping bag.

### D5. No forced reminders

There is no grace period that forces a reminder. Only good moments trigger it.

### D6. Break length is flexible **[Research: R2]**

- No fixed length. The break ends only when the player clicks **"I'm back"** (see D14).
- The popup shows a **countdown to a suggested length** (default 3 minutes, matching the sleeping bag's full +3% buff) and plays a sound when it reaches zero, so the player knows they can sit back down.

### D7. Break flow for v1

- **Countdown timer** as described in D6.
- **Manual return:** only the "I'm back" button ends a break (D14).
- **Popup buttons:** "Taking a break", "Snooze", "Skip this one".

### D8. What resets the play timer **[Research: R6]**

Any of these sets the play timer back to zero:

- Finishing a break (clicking "I'm back", or the D14 safety net).
- Being logged out for 5 minutes or more (checked on next login).
- The game's AFK flag being on for 5 minutes or more.
- Clicking "Skip this one".

### D9. Always-on UI **[Research: R8, R14]**

- **Default: a small movable widget** showing time until the next break, the "break due" state, and the rested pool (for example "42% rested, +1.2% this break").
- **Option: a minimap button** with a tooltip carrying the same information. The user can choose either or both.

### D10. Account-wide timer and settings

- The play timer and all settings are **account-wide** (`GUADB`): switching alts keeps the same timer, because the player's body doesn't care which character they're on.
- Per character (`GUADBChar`): sleeping bag ownership and rested XP data.

### D11. Unanswered popup stays on screen **[Research: R12]**

If the popup appears and the good moment ends before the player answers (for example the flight lands), the popup **stays** until a button is clicked. It must not block play (no keyboard capture, no protected frames, safe to stay up during combat).

### D12. Snooze is 15 minutes

"Snooze" waits 15 minutes, then the reminder returns at the next good moment.

### D13. Settings UI: Options panel plus slash commands **[Research: R9]**

- A settings page under Esc > Options > AddOns with sliders and checkboxes.
- `/gua` commands for power users; `/gua` with no arguments (or `/gua config`) opens the panel.

### D14. Breaks end manually **[Research: R13]**

Only the "I'm back" button ends a break. Movement, casting and combat do not end it, so bumping the mouse or keyboard never cuts a break short.

**Safety net:** if the player is clearly playing again (active for 5+ minutes during a break: moving, casting or in combat), GUA ends the break automatically and restarts the play timer. This is the one exception to manual-only.

### D15. One-click sleeping bag button **[Research: R1, R2, R12]**

- The break popup has a secure **"Place sleeping bag"** button that uses the Cozy Sleeping Bag and starts the break in one click.
- Shown only when: the character owns the bag, is out of combat, and is not already in a rested zone.
- Built with `SecureActionButtonTemplate`, attributes set out of combat (see `.claude/standards/combat-and-taint.md`).
- To keep D11 working, the secure button is its **own top-level frame** anchored to the popup, not a child of it. It hides when combat starts, so the popup itself stays an ordinary frame that can show and hide during combat.

### D16. Quiet zones **[Research: R7]**

No reminders inside **dungeons, raids, battlegrounds or arenas**, even if a good moment happens there. Waiting in a dungeon queue in the open world still counts as a good moment.

### D17. Logout warning popup **[Research: R1, R3, R4]**

- When logging out outside a rested zone (the 20-second countdown starts), GUA shows a popup: "Not rested: you'll only earn a quarter of the rested XP."
- If the character owns the sleeping bag, the popup has a **"Place sleeping bag & log out"** button.

### D18. Look and tone

- **Native Blizzard look:** the game's own frame borders, fonts and buttons, so GUA blends in with the default UI.
- **Friendly, light tone:** for example "Long flight ahead. Good time to stand up and stretch!" Text adapts to the moment (flight, inn, queue, idle).

### D19. Random break tip

Each break popup shows one short, random suggestion: roll your shoulders, drink water, look 20 feet away for 20 seconds, and so on.

## Later versions (not v1)

- **Steer breaks to rested zones.** Dropped from v1 because the game has no API for distance to the nearest inn. Ideas for later: suggest hearthing when the Hearthstone is ready, or a hand-made list of zones with inns.
- **v2: Stats and streaks.** Breaks taken and skipped per day, streaks, total rested XP earned during breaks.
- **Later: Stand-up desk support** with a short onboarding that asks whether the player has a stand-up desk.

## Open questions

_None right now._

## Research needed

Not researched yet. Each item has a GitHub issue labeled `research`. Decisions that depend on an item are flagged in their heading with **[Research: R#]**. Answer these before building the flagged decision.

| ID | Issue | Question | Blocks |
|---|---|---|---|
| R1 | [#1](https://github.com/estebancas/gua/issues/1) | Is the Cozy Sleeping Bag a bag item or a toy? Its item/toy ID, how to detect that the character owns it, and how to use it from a secure button. | D4, D15, D17 |
| R2 | [#2](https://github.com/estebancas/gua/issues/2) | Does time online inside the sleeping bag build rested XP, or only give the +3% buff? Sources disagree (see rested-xp.md). Also confirm the +3% buff duration. | D4, D6, D15 |
| R3 | [#3](https://github.com/estebancas/gua/issues/3) | Does placing the sleeping bag cancel a logout countdown already in progress? Can an addon start a logout after placing it, or is logout protected? | D17 |
| R4 | [#4](https://github.com/estebancas/gua/issues/4) | Which event or check detects the logout countdown (for example `PLAYER_CAMPING`), and whether it fires for instant logouts. | D17 |
| R5 | [#5](https://github.com/estebancas/gua/issues/5) | How to detect each good moment in the Forever client: taxi flight, rested zone, idle (no movement or action), dungeon queue, ghost run, loading screens, boat and zeppelin rides. Boats and zeppelins likely have no direct API. | D2 |
| R6 | [#6](https://github.com/estebancas/gua/issues/6) | How to detect the game's AFK flag and how long it has been on. | D8 |
| R7 | [#7](https://github.com/estebancas/gua/issues/7) | How to tell dungeons, raids, battlegrounds and arenas apart from the open world. | D16 |
| R8 | [#8](https://github.com/estebancas/gua/issues/8) | How to read the rested pool and measure how much a break earned (for example `GetXPExhaustion`). | D4, D9 |
| R9 | [#9](https://github.com/estebancas/gua/issues/9) | The settings API for an Esc > Options > AddOns page in this client (modern `Settings` API or older `InterfaceOptions`). | D13 |
| R10 | [#10](https://github.com/estebancas/gua/issues/10) | Built-in sound IDs for the sound dropdown, and how to make sound play while the game is in the background without changing the player's own sound settings. | D3 |
| R11 | [#11](https://github.com/estebancas/gua/issues/11) | Whether flashing the dock/taskbar icon is available to addons (for example `FlashClientIcon`). | D3 |
| R12 | [#12](https://github.com/estebancas/gua/issues/12) | Secure button rules: confirm a top-level `SecureActionButtonTemplate` frame anchored to a normal popup can be hidden safely when combat starts. | D11, D15 |
| R13 | [#13](https://github.com/estebancas/gua/issues/13) | Whether Forever has Midnight-style "secret values" that block any of the reads above, mainly during combat (D14 safety net needs combat and casting state). | D14, all |
| R14 | [#14](https://github.com/estebancas/gua/issues/14) | Best way to build a minimap button in this client (custom frame or a library such as LibDBIcon). | D9 |
