-- Checks a pull request title against the commit format (issue #58). The
-- title becomes the squash commit subject on main, so it follows the same
-- rules as the global commit-msg hook: "{emoji} {type}: {subject}", with a
-- subject of 45 characters or fewer.
--
-- Usage: PR_TITLE="🚀 feat: add login" lua scripts/check-pr-title.lua
-- Exit code: 0 ok, 1 bad title.

local M = {}

M.MAX_SUBJECT = 45

-- Same table as the commit hook and ~/.cz-config.js.
M.TYPES = {
  { emoji = "🚀", type = "feat" },
  { emoji = "🐛", type = "fix" },
  { emoji = "📝", type = "docs" },
  { emoji = "💅", type = "style" },
  { emoji = "♻️", type = "ref" },
  { emoji = "⚡️", type = "perf" },
  { emoji = "🧪", type = "test" },
  { emoji = "🔧", type = "chore" },
}

-- Emoji variation selector U+FE0F: optional in ♻️ and ⚡️.
local VS16 = "\239\184\143"

local function stripVS16(s)
  return (s:gsub(VS16, ""))
end

-- Characters, not bytes: counts every byte that doesn't continue a UTF-8
-- sequence.
function M.length(s)
  local _, n = s:gsub("[^\128-\191]", "")
  return n
end

-- Returns true, or false and the reason.
function M.check(title)
  title = title or ""
  if not title:find("%S") then
    return false, "the title is empty"
  end
  -- GitHub's own revert PRs are titled 'Revert "<title>"'.
  if title:find('^Revert "') then
    return true
  end
  local plain = stripVS16(title)
  for _, t in ipairs(M.TYPES) do
    local prefix = stripVS16(t.emoji) .. " " .. t.type .. ": "
    if plain:sub(1, #prefix) == prefix then
      local subject = plain:sub(#prefix + 1)
      if not subject:find("%S") then
        return false, "the subject is empty"
      end
      local n = M.length(subject)
      if n > M.MAX_SUBJECT then
        return false, ("the subject is %d characters, keep it to %d or fewer"):format(n, M.MAX_SUBJECT)
      end
      return true
    end
  end
  return false, "the title must start with a matching '{emoji} {type}: '"
end

function M.usage()
  local lines = { "  format: {emoji} {type}: {subject}   (subject <= " .. M.MAX_SUBJECT .. " characters)", "  e.g.    🚀 feat: add login", "" }
  for _, t in ipairs(M.TYPES) do
    lines[#lines + 1] = "    " .. t.emoji .. " " .. t.type
  end
  return table.concat(lines, "\n")
end

-- `write` defaults to print; specs pass their own.
function M.main(title, write)
  write = write or print
  local ok, reason = M.check(title)
  if ok then
    write("PR title ok: " .. title)
    return 0
  end
  write("PR title: " .. reason .. ".\n\n" .. M.usage())
  return 1
end

if arg and arg[0] and arg[0]:find("check%-pr%-title%.lua$") then
  os.exit(M.main(os.getenv("PR_TITLE")))
end

return M
