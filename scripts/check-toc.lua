-- Checks gua.toc against the repo:
--   * "## Interface:" is present and numeric (a comma-separated list is allowed)
--   * "## Version: @project-version@" is present, so the packager sets the version
--   * every listed file is tracked by git with the exact same case, or comes
--     from an external declared in .pkgmeta
--   * no listed file is in a folder that .pkgmeta leaves out of the zip
--   * every addon .lua file is listed. Only spec/, scripts/, .lua/ and
--     .pkgmeta externals are exempt; a folder name such as Libs/ is not.
-- Run from the repo root: lua scripts/check-toc.lua

local repo = dofile("scripts/repo.lua")

local errors = {}
local function fail(message)
  errors[#errors + 1] = message
end

local toc = repo.readToc()
if not toc then
  print(repo.TOC .. " not found. Run from the repo root.")
  os.exit(1)
end

local tracked = repo.tracked()
local ignored = repo.ignored()
local listed = {}

for _, entry in ipairs(toc.files) do
  local path = entry.path
  local where = ("%s:%d: "):format(repo.TOC, entry.line)
  listed[path] = true
  if not tracked[path] and not repo.isExternal(path) then
    fail(where .. ("listed file %q is not in the repo (check spelling and case)"):format(path))
  end
  for _, prefix in ipairs(ignored) do
    if repo.under(path, prefix) then
      fail(where .. ("listed file %q is left out of the zip by '%s' in .pkgmeta ignore:, so the game would fail to load it"):format(path, prefix))
    end
  end
end

if not toc.interface then
  fail(repo.TOC .. ": missing '## Interface:' line")
elseif not toc.interface:match("^%d+[%d,%s]*$") then
  fail(("%s: '## Interface: %s' must be a number, such as 16001"):format(repo.TOC, toc.interface))
end

if toc.version ~= "@project-version@" then
  fail(("%s: '## Version:' must be '@project-version@' so the packager fills it in (found %q)"):format(repo.TOC, tostring(toc.version)))
end

for path in pairs(tracked) do
  if path:find("%.lua$") and not repo.isDev(path) and not repo.isExternal(path) and not listed[path] then
    fail(("%s is not listed in %s, so the game will never load it. Add it in load order."):format(path, repo.TOC))
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
