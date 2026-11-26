-- Checks gua.toc against the repo:
--   * "## Interface:" is present and numeric (a comma-separated list is allowed)
--   * "## Version: @project-version@" is present, so the packager sets the version
--   * every listed file is tracked by git, with the exact same case
--   * every addon .lua file is listed (tests, tooling and libraries excepted)
-- Run from the repo root: lua scripts/check-toc.lua

local TOC = "gua.toc"
local SKIP = { "^spec/", "^scripts/", "^%.lua/", "^[Ll]ibs/" }

local errors = {}
local function fail(message)
  errors[#errors + 1] = message
end

-- Exact-case set of tracked files. The macOS file system ignores case, so a
-- plain "does the file exist" check would miss a wrong-case entry.
local tracked = {}
local list = assert(io.popen("git ls-files"))
for path in list:lines() do
  tracked[path] = true
end
list:close()

local file = io.open(TOC, "r")
if not file then
  print(TOC .. " not found. Run from the repo root.")
  os.exit(1)
end

local interface, version
local listed = {}
local number = 0

for line in file:lines() do
  number = number + 1
  line = line:gsub("\r$", "")
  local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
  if key == "Interface" then
    interface = value
  elseif key == "Version" then
    version = value
  elseif not line:find("^#") and line:find("%S") then
    local path = line:match("^%s*(.-)%s*$"):gsub("\\", "/")
    listed[path] = true
    if not tracked[path] then
      fail(("%s:%d: listed file %q is not in the repo (check spelling and case)"):format(TOC, number, path))
    end
  end
end
file:close()

if not interface then
  fail(TOC .. ": missing '## Interface:' line")
elseif not interface:match("^%d+[%d,%s]*$") then
  fail(("%s: '## Interface: %s' must be a number, such as 16001"):format(TOC, interface))
end

if version ~= "@project-version@" then
  fail(("%s: '## Version:' must be '@project-version@' so the packager fills it in (found %q)"):format(TOC, tostring(version)))
end

local function skipped(path)
  for _, prefix in ipairs(SKIP) do
    if path:find(prefix) then
      return true
    end
  end
  return false
end

for path in pairs(tracked) do
  if path:find("%.lua$") and not skipped(path) and not listed[path] then
    fail(("%s is not listed in %s, so the game will never load it. Add it in load order."):format(path, TOC))
  end
end

if #errors > 0 then
  table.sort(errors)
  for _, message in ipairs(errors) do
    print(message)
  end
  os.exit(1)
end

print("TOC check: OK")
