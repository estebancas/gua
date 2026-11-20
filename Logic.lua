-- Pure functions only: no WoW API calls, so everything here can be unit tested
-- outside the game (see spec/logic_spec.lua).
local _, ns = ...

local Logic = {}
ns.Logic = Logic

-- Copies every default missing from target, recursing into nested tables.
-- Values the user already has are kept.
function Logic.mergeDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = {}
      end
      Logic.mergeDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
  return target
end

-- Splits slash command input into a lowercase command and the rest of the text.
-- "  Debug  on " -> "debug", "on"
function Logic.parseCommand(input)
  local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  return command:lower(), rest
end
