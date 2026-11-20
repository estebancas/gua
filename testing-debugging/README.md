# Testing and debugging

How to test and debug WoW: Forever addons. Compiled 19 November 2026.

WoW has no step debugger: no breakpoints and no attaching an IDE. Debugging means error capture, printing and inspecting state in-game, plus unit tests for logic that can run outside the game.

| File | Covers |
|---|---|
| [dev-workflow.md](dev-workflow.md) | Linking the repo into the game and the edit, reload, check loop |
| [in-game-tools.md](in-game-tools.md) | Slash commands, debug addons, error and taint logs |
| [offline-testing.md](offline-testing.md) | Linting and unit tests without the game |
| [profiling.md](profiling.md) | Measuring CPU and memory use |
| [checklist.md](checklist.md) | What to test before each release |
