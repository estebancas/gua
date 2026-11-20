local addonName, ns = ...
local Logic = ns.Logic

-- Bump DB_VERSION and add a step to migrate() whenever the saved data shape changes.
local DB_VERSION = 1

local DEFAULTS = {
  version = DB_VERSION,
  enabled = true,
  debug = false,
}

local PREFIX = "|cff33ff99GUA|r"

function ns.Print(...)
  print(PREFIX, ...)
end

function ns.Debug(...)
  if ns.db and ns.db.debug then
    print(PREFIX, "|cff999999[debug]|r", ...)
  end
end

local function migrate(db)
  -- Example for a future version:
  -- if db.version < 2 then
  --   db.newField = db.oldField
  --   db.oldField = nil
  -- end
  db.version = DB_VERSION
end

-- Event frame: each event is handled by a method with the same name.
local events = CreateFrame("Frame")
ns.events = events

events:SetScript("OnEvent", function(self, event, ...)
  local handler = self[event]
  if handler then
    handler(self, ...)
  end
end)

function events:ADDON_LOADED(name)
  if name ~= addonName then
    return
  end
  self:UnregisterEvent("ADDON_LOADED")

  GUADB = GUADB or {}
  Logic.mergeDefaults(GUADB, DEFAULTS)
  migrate(GUADB)
  ns.db = GUADB

  ns.Debug("saved variables loaded, version", ns.db.version)
end

function events:PLAYER_LOGIN()
  self:UnregisterEvent("PLAYER_LOGIN")
  if not ns.db.enabled then
    return
  end
  ns.Debug("player login")
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
