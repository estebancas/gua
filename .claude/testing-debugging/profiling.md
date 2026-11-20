# Profiling

## Time a block of code

```lua
local start = debugprofilestop()
-- code to measure
print(("took %.3f ms"):format(debugprofilestop() - start))
```

Measure over many calls and average. One call is usually too fast to measure reliably.

## Memory use

```lua
/run UpdateAddOnMemoryUsage(); print(GetAddOnMemoryUsage("MyAddon"), "KB")
```

- Run it twice a few minutes apart during normal play. Memory that keeps climbing points to tables or closures created in hot paths.
- `collectgarbage("count")` gives total Lua memory for all addons.

## Per-addon CPU (Unverified for Forever)

Modern Retail clients have a built-in addon profiler, `C_AddOnProfiler`, that reports CPU time per addon. Check whether Forever has it with `/dump C_AddOnProfiler`. If it does, compare your addon's numbers in quiet moments and in busy fights.

## Where to look first

1. `OnUpdate` scripts.
2. Handlers for frequent events: `COMBAT_LOG_EVENT_UNFILTERED`, `UNIT_AURA`, `UNIT_HEALTH`, `BAG_UPDATE`.
3. Loops that call the API for every item, aura or group member.

Fixes are listed in [../standards/performance.md](../standards/performance.md).
