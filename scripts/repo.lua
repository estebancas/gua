-- Shared helpers for the check scripts: which files exist, which the game
-- loads (gua.toc) and which the packager leaves out or pulls in (.pkgmeta).
-- Load with: local repo = dofile("scripts/repo.lua")

local repo = {}

repo.TOC = "gua.toc"
repo.PKGMETA = ".pkgmeta"

-- Folders of tests and tooling: never shipped and never loaded by the game.
local DEV_PREFIXES = { "spec/", "scripts/", ".lua/" }

local function trim(text)
  return (text:match("^%s*(.-)%s*$"))
end

local function under(path, prefix)
  prefix = prefix:gsub("/*$", "")
  return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end
repo.under = under

-- Exact-case set of files tracked by git. The macOS file system ignores case,
-- so "does the file exist" would miss a wrong-case entry.
function repo.tracked()
  local files = {}
  local list = assert(io.popen("git ls-files"))
  for path in list:lines() do
    files[path] = true
  end
  list:close()
  return files
end

-- Reads the top-level list or map under `key:` in .pkgmeta (a small YAML
-- subset: "  - item" or "  name: value" lines).
local function pkgmetaSection(key)
  local items = {}
  local file = io.open(repo.PKGMETA, "r")
  if not file then
    return items
  end
  local inside = false
  for line in file:lines() do
    line = line:gsub("\r$", "")
    if line:match("^%S") then
      inside = line:match("^" .. key .. ":%s*$") ~= nil
    elseif inside then
      local item = line:match("^%s+%-%s+(.-)%s*$") or line:match("^  ([^%s:#][^:]*):")
      if item then
        items[#items + 1] = trim(item):gsub("^[\"']", ""):gsub("[\"']$", "")
      end
    end
  end
  file:close()
  return items
end

-- Paths the packager fills from other repositories at build time.
function repo.externals()
  return pkgmetaSection("externals")
end

-- Paths the packager leaves out of the zip.
function repo.ignored()
  return pkgmetaSection("ignore")
end

function repo.isExternal(path)
  for _, prefix in ipairs(repo.externals()) do
    if under(path, prefix) then
      return true
    end
  end
  return false
end

function repo.isDev(path)
  for _, prefix in ipairs(DEV_PREFIXES) do
    if under(path, prefix) then
      return true
    end
  end
  return false
end

-- Parses gua.toc. Returns nil when it is missing, else a table with
-- `interface`, `version` and `files` (a list of { path, line }).
function repo.readToc()
  local file = io.open(repo.TOC, "r")
  if not file then
    return nil
  end
  local toc = { files = {} }
  local number = 0
  for line in file:lines() do
    number = number + 1
    line = line:gsub("\r$", "")
    local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
    if key == "Interface" then
      toc.interface = value
    elseif key == "Version" then
      toc.version = value
    elseif not line:find("^#") and line:find("%S") then
      toc.files[#toc.files + 1] = { path = trim(line):gsub("\\", "/"), line = number }
    end
  end
  file:close()
  return toc
end

return repo
