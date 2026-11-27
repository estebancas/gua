local addonName, ns = ...
local L, Logic = ns.L, ns.Logic

local function onOff(value)
  return value and L["on"] or L["off"]
end

---@type table<string, fun(rest: string?)>
local commands = {}

function commands.toggle()
  ns.db.enabled = not ns.db.enabled
  ns.Print(L["Enabled:"], onOff(ns.db.enabled))
end

function commands.debug()
  ns.db.debug = not ns.db.debug
  ns.Print(L["Debug mode:"], onOff(ns.db.debug))
end

function commands.version()
  ns.Print(C_AddOns.GetAddOnMetadata(addonName, "Version"))
end

function commands.help()
  ns.Print(L["Commands:"])
  print("  /gua toggle - " .. L["turn the addon on or off"])
  print("  /gua debug - " .. L["turn debug messages on or off"])
  print("  /gua version - " .. L["show the addon version"])
end

SLASH_GUA1 = "/gua"
SlashCmdList.GUA = function(input)
  local command, rest = Logic.parseCommand(input)
  local handler = commands[command] or commands.help
  handler(rest)
end
