local _, ns = ...

-- English strings are the keys. A missing translation falls back to the key.
local L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

ns.L = L
