-- Loads an addon file the way WoW does: the chunk receives (addonName, ns).
local helpers = {}

function helpers.loadAddonFile(path, ns)
  ns = ns or {}
  local chunk = assert(loadfile(path))
  chunk("gua", ns)
  return ns
end

return helpers
