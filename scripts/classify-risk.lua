-- Decides whether a change is low-risk (the agent may merge it once every
-- check is green) or risky (the owner merges it). Rules: issue #49.
-- Anything it can't classify is risky.
--
-- Usage, from the repo root (it loads scripts/repo.lua):
--   git diff main...HEAD | lua scripts/classify-risk.lua
--   lua scripts/classify-risk.lua <base> [<head>]    (runs git diff base...head)
-- Prints "risk:low" or "risk:high", then one line per reason.
-- Exit code: 0 low, 1 high, 2 usage error.

local repo = dofile("scripts/repo.lua")

local M = {}

M.MAX_LINES = 300
M.MAX_FILES = 10

-- Paths whose change is always risky, by kind of risk. A pattern ending in
-- "/" matches the folder.
local RISKY_PATHS = {
  {
    rule = "changes the guardrails",
    paths = { ".github/", ".claude/", "scripts/", "CLAUDE.md", ".luacheckrc", ".luacov", "spec/helpers.lua" },
  },
  { rule = "changes what ships", paths = { ".pkgmeta", "LICENSE", "LICENSE.md", ".gitignore" } },
  { rule = "changes product decisions", paths = { "PLAN.md", "rested-xp.md" } },
}

-- Words in added or removed Lua/XML lines that touch secure code or the
-- shape of the saved data.
local DANGEROUS = {
  { pattern = "Secure%w*Template", why = "secure template" },
  { pattern = "%f[%w_]InCombatLockdown%f[^%w_]", why = "combat lockdown check" },
  { pattern = "%f[%w_]SetAttribute%f[^%w_]", why = "secure attribute" },
  { pattern = "%f[%w_]DB_VERSION%f[^%w_]", why = "saved data version" },
  { pattern = "%f[%w_]migrate%s*%(", why = "saved data migration" },
}

local function matchesPath(path, pattern)
  if pattern:sub(-1) == "/" then
    return repo.under(path, pattern)
  end
  return path == pattern
end

local function isCode(path)
  return path:find("%.lua$") ~= nil or path:find("%.xml$") ~= nil
end

local function isSpec(path)
  return path:find("^spec/.+_spec%.lua$") ~= nil
end

-- The kinds of file a low-risk change may touch. Anything else is unknown.
local function isKnownLowRisk(path)
  if isSpec(path) or path:find("%.md$") then
    return true
  end
  return isCode(path) and not repo.under(path, "spec") and not repo.under(path, ".lua")
end

-- Drops a trailing "-- comment" so English words in comments don't count as
-- calls. A "--" inside a string can hide the rest of the line, but CI's
-- forbidden API check still sees it.
local function stripComment(line)
  return (line:gsub("%-%-.*$", ""))
end

-- Reads a git diff into a list of files:
-- { path, oldPath, added = {lines}, removed = {lines}, new, deleted, binary }
function M.parse(text)
  local files = {}
  local current
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    local a, b = line:match("^diff %-%-git a/(.-) b/(.*)$")
    if a then
      current = { path = b, oldPath = a, added = {}, removed = {} }
      files[#files + 1] = current
    elseif line:match("^diff %-%-git ") then
      -- quoted paths (unusual characters): keep the raw line, classify as unknown
      current = { path = line, added = {}, removed = {}, unparsed = true }
      files[#files + 1] = current
    elseif current and line:match("^@@ ") then
      current.inHunk = true
    elseif current and current.inHunk then
      -- Inside a hunk, "--- x" is a removed line, e.g. a Lua comment.
      if line:sub(1, 1) == "+" then
        current.added[#current.added + 1] = line:sub(2)
      elseif line:sub(1, 1) == "-" then
        current.removed[#current.removed + 1] = line:sub(2)
      end
    elseif current then
      -- File header lines (+++/--- are already known from "diff --git").
      if line:match("^new file mode") then
        current.new = true
      elseif line:match("^deleted file mode") then
        current.deleted = true
      elseif line:match("^Binary files") or line:match("^GIT binary patch") then
        current.binary = true
      end
    end
  end
  return files
end

-- Returns "low" or "high", plus a list of reasons ("rule: file").
function M.classify(text)
  local reasons, seen = {}, {}
  local function flag(rule, path)
    local reason = rule .. ": " .. path
    if not seen[reason] then
      seen[reason] = true
      reasons[#reasons + 1] = reason
    end
  end

  local files = M.parse(text)
  if #files == 0 then
    flag("can't classify", "the diff is empty or not a git diff")
  end

  local changedLines = 0
  for _, file in ipairs(files) do
    changedLines = changedLines + #file.added + #file.removed
    local paths = { file.path }
    if file.oldPath and file.oldPath ~= file.path then
      paths[2] = file.oldPath
    end

    for _, path in ipairs(paths) do
      local risky = false
      for _, group in ipairs(RISKY_PATHS) do
        for _, pattern in ipairs(group.paths) do
          if matchesPath(path, pattern) then
            flag(group.rule, path)
            risky = true
          end
        end
      end
      if path:find("%.toc$") then
        flag("changes what ships", path)
        risky = true
      end
      if not risky and (file.unparsed or not isKnownLowRisk(path)) then
        flag("can't classify", path)
      end
    end

    if file.binary then
      flag("can't classify (binary file)", file.path)
    end

    if isSpec(file.oldPath or file.path) then
      if file.deleted then
        flag("weakens checks (spec file deleted)", file.path)
      end
      -- An `it` block removed here and not added back (moved) is a lost test.
      local kept = {}
      for _, line in ipairs(file.added) do
        kept[line:match("^%s*(.-)%s*$")] = true
      end
      for _, line in ipairs(file.removed) do
        if line:find("^%s*it%s*%(") and not kept[line:match("^%s*(.-)%s*$")] then
          flag("weakens checks (test removed)", file.path)
        end
      end
    end

    if isSpec(file.path) then
      for _, line in ipairs(file.added) do
        if line:find("^%s*pending%s*%(") then
          flag("weakens checks (new pending test)", file.path)
        end
      end
    end

    -- Addon code only: dev folders (scripts/, spec/) are flagged by path or
    -- by the test rules above.
    if isCode(file.path) and not repo.isDev(file.path) then
      for _, line in ipairs(file.added) do
        if line:find("%-%-%s*gua%-allow:") then
          flag("weakens checks (new gua-allow comment)", file.path)
        end
        local code = stripComment(line)
        for _, rule in ipairs(repo.FORBIDDEN) do
          if code:find(rule.pattern) then
            flag("dangerous code (forbidden API: " .. rule.why .. ")", file.path)
          end
        end
      end
      local both = {}
      for _, line in ipairs(file.added) do
        both[#both + 1] = line
      end
      for _, line in ipairs(file.removed) do
        both[#both + 1] = line
      end
      for _, line in ipairs(both) do
        for _, rule in ipairs(DANGEROUS) do
          if line:find(rule.pattern) then
            flag("dangerous code (" .. rule.why .. ")", file.path)
          end
        end
      end
    end
  end

  if changedLines > M.MAX_LINES then
    flag("too big to review quickly", ("%d changed lines (limit %d)"):format(changedLines, M.MAX_LINES))
  end
  if #files > M.MAX_FILES then
    flag("too big to review quickly", ("%d files (limit %d)"):format(#files, M.MAX_FILES))
  end

  return #reasons == 0 and "low" or "high", reasons
end

-- The printed report (a list of lines) and the exit code for a diff.
function M.report(text)
  local verdict, reasons = M.classify(text)
  local lines = { "risk:" .. verdict }
  for _, reason in ipairs(reasons) do
    lines[#lines + 1] = "- " .. reason
  end
  return lines, verdict == "low" and 0 or 1
end

-- The git command for `lua scripts/classify-risk.lua <base> [<head>]`, or nil
-- when an argument looks like an option or holds a quote.
function M.diffCommand(base, head)
  head = head or "HEAD"
  for _, ref in ipairs({ base, head }) do
    if ref:find("^%-") or ref:find("['\"]") then
      return nil
    end
  end
  return ("git diff --no-color --no-ext-diff -M '%s...%s'"):format(base, head)
end

function M.main(args)
  local text
  if args[1] then
    local command = M.diffCommand(args[1], args[2])
    if not command then
      io.stderr:write("usage: lua scripts/classify-risk.lua [<base> [<head>]] (or a diff on stdin)\n")
      return 2
    end
    local pipe = assert(io.popen(command))
    text = pipe:read("*a")
    pipe:close()
  else
    text = io.read("*a")
  end
  local lines, code = M.report(text)
  print(table.concat(lines, "\n"))
  return code
end

if arg and arg[0] and arg[0]:find("classify%-risk%.lua$") then
  os.exit(M.main(arg))
end

return M
