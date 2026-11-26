-- Fails when addon code uses an API that runs text as code, talks to other
-- players or touches protected UI. GUA needs none of these, so each use must
-- be justified on the same line with a trailing comment:
--   foo() -- gua-allow: <reason>
-- Run from the repo root: lua scripts/check-forbidden-api.lua

local FORBIDDEN = {
  { pattern = "%f[%w_]loadstring%f[^%w_]", why = "runs a string as code" },
  { pattern = "%f[%w_.:]load%s*%(", why = "runs a string as code" },
  { pattern = "%f[%w_]RunScript%f[^%w_]", why = "runs a string as code" },
  { pattern = "%f[%w_]setfenv%f[^%w_]", why = "changes a function's environment" },
  { pattern = "%f[%w_]getfenv%f[^%w_]", why = "reads a function's environment" },
  { pattern = "SendAddonMessage", why = "sends data to other players" },
  { pattern = "CHAT_MSG_ADDON", why = "receives data from other players" },
  { pattern = "RegisterAddonMessagePrefix", why = "receives data from other players" },
  { pattern = "%f[%w_]SendChatMessage%f[^%w_]", why = "speaks in chat for the player" },
  { pattern = "%f[%w_]EditMacro%f[^%w_]", why = "changes the player's macros" },
  { pattern = "%f[%w_]CreateMacro%f[^%w_]", why = "changes the player's macros" },
  { pattern = "%f[%w_]hooksecurefunc%f[^%w_]", why = "hooks Blizzard code; check combat-and-taint.md" },
}

local ALLOW = "%-%-%s*gua%-allow:%s*%S"

-- Addon code only: tests, tooling and third-party libraries are skipped.
local SKIP = { "^spec/", "^scripts/", "^%.lua/", "^[Ll]ibs/" }

local function skipped(path)
  for _, prefix in ipairs(SKIP) do
    if path:find(prefix) then
      return true
    end
  end
  return false
end

local list = assert(io.popen("git ls-files -- '*.lua'"))
local failures = 0

for path in list:lines() do
  if not skipped(path) then
    local file = assert(io.open(path, "r"))
    local number = 0
    for line in file:lines() do
      number = number + 1
      if not line:find(ALLOW) then
        for _, rule in ipairs(FORBIDDEN) do
          local start = line:find(rule.pattern)
          if start then
            failures = failures + 1
            print(("%s:%d: forbidden API (%s): %s"):format(path, number, rule.why, line:match("^%s*(.-)%s*$")))
          end
        end
      end
    end
    file:close()
  end
end
list:close()

if failures > 0 then
  print(("\n%d forbidden API use(s). Remove them, or justify each on the same line with '-- gua-allow: <reason>'."):format(failures))
  print("A PR that adds a gua-allow comment is risky and needs the owner's review.")
  os.exit(1)
end

print("Forbidden API check: OK")
