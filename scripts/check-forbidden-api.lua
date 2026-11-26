-- Fails when addon code uses an API that runs text as code, looks up globals
-- by a computed name, talks to other players or touches protected UI. GUA
-- needs none of these, so each use must be justified with a comment that ends
-- the same line:
--   foo() -- gua-allow: <reason>
--
-- This catches mistakes, not someone hiding a call on purpose: a name built
-- at run time (string.char, table lookups) can still get past it. Reviews and
-- the owner's approval of risky PRs cover that.
--
-- Scanned: every file gua.toc lists, whatever its folder, plus every tracked
-- .lua and .xml file outside spec/, scripts/, .lua/ and .pkgmeta externals.
-- Comments are ignored; string contents are not (so _G["loadstring"] fails).
-- Run from the repo root: lua scripts/check-forbidden-api.lua

local repo = dofile("scripts/repo.lua")

-- The whole word `name`.
local function word(name)
  return "%f[%w_]" .. name .. "%f[^%w_]"
end
-- The whole word `name`, not after "." or ":", so a method such as
-- `obj:load()` is fine.
local function freeWord(name)
  return "%f[%w_.:]" .. name .. "%f[^%w_]"
end

local FORBIDDEN = {
  { pattern = word("loadstring"), why = "runs a string as code" },
  { pattern = freeWord("load"), why = "runs a string or function as code" },
  { pattern = word("RunScript"), why = "runs a string as code" },
  { pattern = word("setfenv"), why = "changes a function's environment" },
  { pattern = word("getfenv"), why = "reads a function's environment" },
  { pattern = "%f[%w_]_G%s*%[", why = "looks up a global by a computed name, which can hide any call" },
  { pattern = word("getglobal"), why = "looks up a global by a computed name, which can hide any call" },
  { pattern = "%f[%w_]rawget%s*%(%s*_G%f[^%w_]", why = "looks up a global by a computed name, which can hide any call" },
  { pattern = "SendAddonMessage", why = "sends data to other players" },
  { pattern = "CHAT_MSG_ADDON", why = "receives data from other players" },
  { pattern = "RegisterAddonMessagePrefix", why = "receives data from other players" },
  { pattern = word("SendChatMessage"), why = "speaks in chat for the player" },
  { pattern = word("EditMacro"), why = "changes the player's macros" },
  { pattern = word("CreateMacro"), why = "changes the player's macros" },
  { pattern = word("hooksecurefunc"), why = "hooks Blizzard code; check combat-and-taint.md" },
}

-- Accepted only as the comment that ends the line, with a reason.
local ALLOW = "^%-%-%s*gua%-allow:%s*%S"

-- Splits Lua source into lines of code without comments, plus the line
-- comment ("-- ...") that ends each line, if any. Strings stay in the code.
local function splitLua(text)
  local lines = { { code = {}, comment = nil } }
  local i, len = 1, #text

  local function add(chunk)
    local current = lines[#lines].code
    current[#current + 1] = chunk
  end
  local function newline()
    lines[#lines + 1] = { code = {}, comment = nil }
  end
  -- Adds text that may span lines (long strings), keeping line numbers right.
  local function addMultiline(chunk, keep)
    local first = true
    for part in (chunk .. "\n"):gmatch("(.-)\n") do
      if not first then
        newline()
      end
      first = false
      if keep then
        add(part)
      end
    end
  end

  while i <= len do
    local c = text:sub(i, i)
    if c == "\n" then
      newline()
      i = i + 1
    elseif text:sub(i, i + 1) == "--" then
      local equals = text:match("^%[(=*)%[", i + 2)
      if equals then
        local close = "]" .. equals .. "]"
        local stop = text:find(close, i, true)
        stop = stop and stop + #close - 1 or len
        addMultiline(text:sub(i, stop), false)
        i = stop + 1
      else
        local stop = text:find("\n", i, true) or len + 1
        lines[#lines].comment = text:sub(i, stop - 1)
        i = stop
      end
    elseif c == '"' or c == "'" then
      local j = i + 1
      while j <= len do
        local d = text:sub(j, j)
        if d == "\\" then
          j = j + 2
        elseif d == c or d == "\n" then
          break
        else
          j = j + 1
        end
      end
      addMultiline(text:sub(i, j), true) -- a "\" can continue a string on the next line
      i = j + 1
    elseif c == "[" and text:match("^%[=*%[", i) then
      local equals = text:match("^%[(=*)%[", i)
      local close = "]" .. equals .. "]"
      local stop = text:find(close, i, true)
      stop = stop and stop + #close - 1 or len
      addMultiline(text:sub(i, stop), true)
      i = stop + 1
    else
      local stop = text:find("[%-\"'%[\n]", i) or len + 1
      if stop == i then
        stop = i + 1
      end
      add(text:sub(i, stop - 1))
      i = stop
    end
  end

  for index, line in ipairs(lines) do
    lines[index] = { code = table.concat(line.code), comment = line.comment }
  end
  return lines
end

-- XML (inline <Script> blocks) is scanned as plain text.
local function splitPlain(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = { code = line }
  end
  return lines
end

local files, seen = {}, {}
local function add(path)
  if not seen[path] then
    seen[path] = true
    files[#files + 1] = path
  end
end

local toc = repo.readToc()
if toc then
  for _, entry in ipairs(toc.files) do
    if not repo.isExternal(entry.path) then
      add(entry.path)
    end
  end
end
for path in pairs(repo.tracked()) do
  if (path:find("%.lua$") or path:find("%.xml$")) and not repo.isDev(path) and not repo.isExternal(path) then
    add(path)
  end
end
table.sort(files)

local failures = 0
for _, path in ipairs(files) do
  local file = io.open(path, "r")
  if file then
    local text = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    local lines = path:find("%.lua$") and splitLua(text) or splitPlain(text)
    for number, line in ipairs(lines) do
      local allowed = line.comment and line.comment:find(ALLOW)
      if not allowed then
        for _, rule in ipairs(FORBIDDEN) do
          if line.code:find(rule.pattern) then
            failures = failures + 1
            print(("%s:%d: forbidden API (%s): %s"):format(path, number, rule.why, line.code:match("^%s*(.-)%s*$")))
          end
        end
      end
    end
  end
end

if failures > 0 then
  print(("\n%d forbidden API use(s). Remove them, or justify each with a comment that ends the line: '-- gua-allow: <reason>'."):format(failures))
  print("A PR that adds a gua-allow comment is risky and needs the owner's review.")
  os.exit(1)
end

print(("Forbidden API check: OK (%d files)"):format(#files))
