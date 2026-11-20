# Performance

All addons share one Lua interpreter with the game UI. A slow addon lowers the player's frame rate, and garbage collection pauses cause stutter.

## Rules

1. **Events over polling.** Register for the specific event that signals a change. Use `RegisterUnitEvent(event, "player")` to receive unit events for one unit only.
2. **Avoid `OnUpdate`.** It runs every frame. If needed, throttle it:

   ```lua
   local elapsedTotal = 0
   frame:SetScript("OnUpdate", function(self, elapsed)
     elapsedTotal = elapsedTotal + elapsed
     if elapsedTotal < 0.2 then return end
     elapsedTotal = 0
     -- work
   end)
   ```
   Prefer `C_Timer.NewTicker`, and hide or unset `OnUpdate` when idle.
3. **Cache globals as locals** at the top of files that run hot code: `local GetTime, UnitHealth = GetTime, UnitHealth`. Local lookups are faster than global lookups.
4. **Don't create garbage in hot paths.** No new tables, closures or string concatenation in `OnUpdate` or in frequent events (`COMBAT_LOG_EVENT_UNFILTERED`, `UNIT_AURA`). Reuse tables and clear them with `wipe(t)`.
5. **Reuse frames.** Frames are never freed. Use a frame pool (`CreateFramePool`) instead of creating new frames.
6. **Batch bursts.** Some events fire many times in a row (`BAG_UPDATE`). Set a flag and process once on the next frame with `C_Timer.After(0, fn)`.
7. **Load on demand.** Large optional parts (options screens) can be split into a separate addon with `## LoadOnDemand: 1`.
8. **Keep saved variables small.** They are parsed at every login.

## Measuring

- `debugprofilestop()` returns milliseconds with high precision. Wrap a block to time it.
- `UpdateAddOnMemoryUsage()` then `GetAddOnMemoryUsage(addonName)` gives memory in KB.
- **Unverified:** the `C_AddOnProfiler` API, if present in Forever, reports CPU use per addon.

See [../testing-debugging/profiling.md](../testing-debugging/profiling.md) for a full profiling workflow.
