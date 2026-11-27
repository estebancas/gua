-- Specs for scripts/classify-risk.lua: one case per rule in issue #49.
local risk = dofile("scripts/classify-risk.lua")

-- A one-hunk git diff for `path`. opts: added, removed (lists of lines),
-- old (renamed from), new, deleted, binary.
local function diff(path, opts)
  opts = opts or {}
  local old = opts.old or path
  local out = { ("diff --git a/%s b/%s"):format(old, path) }
  if opts.new then
    out[#out + 1] = "new file mode 100644"
  end
  if opts.deleted then
    out[#out + 1] = "deleted file mode 100644"
  end
  if opts.binary then
    out[#out + 1] = ("Binary files a/%s and b/%s differ"):format(old, path)
    return table.concat(out, "\n")
  end
  out[#out + 1] = "--- " .. (opts.new and "/dev/null" or "a/" .. old)
  out[#out + 1] = "+++ " .. (opts.deleted and "/dev/null" or "b/" .. path)
  out[#out + 1] = "@@ -1,1 +1,1 @@"
  for _, line in ipairs(opts.removed or {}) do
    out[#out + 1] = "-" .. line
  end
  for _, line in ipairs(opts.added or { "local x = 1" }) do
    out[#out + 1] = "+" .. line
  end
  return table.concat(out, "\n")
end

local function verdict(...)
  local level, reasons = risk.classify(table.concat({ ... }, "\n"))
  return level, table.concat(reasons, "\n")
end

local function assertHigh(expected, ...)
  local level, reasons = verdict(...)
  assert.are.equal("high", level)
  assert.truthy(reasons:find(expected, 1, true), "missing reason '" .. expected .. "' in:\n" .. reasons)
end

describe("classify-risk", function()
  describe("low risk", function()
    it("accepts addon code with its specs", function()
      assert.are.equal("low", (verdict(diff("Logic.lua"), diff("spec/logic_spec.lua", { added = { 'it("adds", function() end)' } }))))
    end)

    it("accepts locale strings, docs and UI code", function()
      assert.are.equal("low", (verdict(diff("Locale.lua"), diff("README.md", { added = { "text" } }), diff("UI.xml", { added = { "<Frame/>" } }))))
    end)

    it("accepts a removed Lua comment, which looks like a --- header", function()
      assert.are.equal("low", (verdict(diff("Logic.lua", { removed = { "-- old note" }, added = { "-- new note" } }))))
    end)

    it("accepts a test moved within its spec file", function()
      local line = 'it("parses", function() end)'
      assert.are.equal("low", (verdict(diff("spec/logic_spec.lua", { removed = { line }, added = { "  " .. line } }))))
    end)
  end)

  describe("risky paths", function()
    it("flags the guardrails", function()
      for _, path in ipairs({ ".github/workflows/ci.yml", ".claude/settings.json", "scripts/test.sh", "CLAUDE.md", ".luacheckrc", ".luacov", "spec/helpers.lua", ".github/CODEOWNERS" }) do
        assertHigh("changes the guardrails: " .. path, diff(path))
      end
    end)

    it("flags what ships", function()
      for _, path in ipairs({ ".pkgmeta", "gua.toc", "LICENSE", ".gitignore" }) do
        assertHigh("changes what ships: " .. path, diff(path))
      end
    end)

    it("flags product decisions", function()
      assertHigh("changes product decisions: PLAN.md", diff("PLAN.md"))
      assertHigh("changes product decisions: rested-xp.md", diff("rested-xp.md"))
    end)

    it("flags both sides of a rename", function()
      assertHigh("changes the guardrails: scripts/old.lua", diff("Moved.lua", { old = "scripts/old.lua" }))
    end)
  end)

  describe("weakened checks", function()
    it("flags a deleted spec file", function()
      assertHigh("spec file deleted", diff("spec/logic_spec.lua", { deleted = true, added = {}, removed = { "x" } }))
    end)

    it("flags a removed it block", function()
      assertHigh("test removed", diff("spec/logic_spec.lua", { removed = { '  it("parses", function()' }, added = {} }))
    end)

    it("flags a new pending test", function()
      assertHigh("new pending test", diff("spec/logic_spec.lua", { added = { 'pending("later")' } }))
      assertHigh("new pending test", diff("spec/logic_spec.lua", { added = { 'it("x", function() pending("y") end)' } }))
      assertHigh("new pending test", diff("spec/logic_spec.lua", { added = { '  it("has no body yet")' } }))
    end)

    it("flags a spec file renamed away, with or without edits", function()
      local pure = table.concat({
        "diff --git a/spec/logic_spec.lua b/spec/logic_spec.md",
        "similarity index 100%",
        "rename from spec/logic_spec.lua",
        "rename to spec/logic_spec.md",
      }, "\n")
      assertHigh("spec file moved or renamed away): spec/logic_spec.lua", pure)
      assertHigh("renamed away", diff("docs/logic_spec.md", { old = "spec/logic_spec.lua", added = { "text" } }))
    end)

    it("accepts a spec file renamed to another spec file", function()
      local renamed = table.concat({
        "diff --git a/spec/logic_spec.lua b/spec/rules_spec.lua",
        "similarity index 100%",
        "rename from spec/logic_spec.lua",
        "rename to spec/rules_spec.lua",
      }, "\n")
      assert.are.equal("low", (verdict(renamed)))
    end)

    it("flags a new gua-allow comment", function()
      assertHigh("new gua-allow comment", diff("Core.lua", { added = { "foo() -- gua-allow: needed" } }))
    end)
  end)

  describe("dangerous code", function()
    it("flags a forbidden API in added code", function()
      assertHigh("forbidden API", diff("Core.lua", { added = { "loadstring(text)()" } }))
    end)

    it("ignores a forbidden API word in a comment", function()
      assert.are.equal("low", (verdict(diff("Core.lua", { added = { "x() -- load order matters" } }))))
    end)

    it("flags secure code, added or removed", function()
      assertHigh("secure template", diff("UI.lua", { added = { 'CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")' } }))
      assertHigh("combat lockdown check", diff("UI.lua", { removed = { "if InCombatLockdown() then return end" }, added = {} }))
      assertHigh("secure attribute", diff("UI.lua", { added = { 'button:SetAttribute("type", "item")' } }))
    end)

    it("flags a change to the saved data shape", function()
      assertHigh("saved data version", diff("Core.lua", { added = { "local DB_VERSION = 2" } }))
      assertHigh("saved data migration", diff("Core.lua", { added = { "migrate(GUADB)" } }))
    end)
  end)

  describe("size", function()
    it("flags more than 300 changed lines", function()
      local lines = {}
      for i = 1, 301 do
        lines[i] = "local x" .. i .. " = 1"
      end
      assertHigh("301 changed lines", diff("Logic.lua", { added = lines }))
    end)

    it("flags more than 10 files", function()
      local files = {}
      for i = 1, 11 do
        files[i] = diff("File" .. i .. ".lua")
      end
      assertHigh("11 files", unpack(files))
    end)
  end)

  describe("unknown changes", function()
    it("flags an empty diff", function()
      assertHigh("the diff is empty", "")
    end)

    it("flags an unknown file type", function()
      assertHigh("can't classify: media/icon.tga", diff("media/icon.tga"))
    end)

    it("flags a binary file", function()
      assertHigh("binary file", diff("media/sound.ogg", { binary = true }))
    end)

    it("flags a spec folder file that is not a spec", function()
      assertHigh("can't classify: spec/stubs.lua", diff("spec/stubs.lua"))
    end)

    it("reads paths holding ' b/' from the +++ and --- lines", function()
      local text = table.concat({
        "diff --git a/scripts/a b/c.lua b/scripts/a b/c.lua",
        "--- a/scripts/a b/c.lua",
        "+++ b/scripts/a b/c.lua",
        "@@ -1 +1 @@",
        "+local x = 1",
      }, "\n")
      assertHigh("changes the guardrails: scripts/a b/c.lua", text)
      local deleted = table.concat({
        "diff --git a/docs/a b/old.md b/docs/a b/old.md",
        "deleted file mode 100644",
        "--- a/docs/a b/old.md",
        "+++ /dev/null",
        "@@ -1 +0,0 @@",
        "-text",
      }, "\n")
      assert.are.equal("low", (verdict(deleted)))
    end)

    it("flags a quoted path it can't parse", function()
      assertHigh("can't classify", 'diff --git "a/we ird.lua" "b/we ird.lua"')
    end)
  end)

  describe("report", function()
    it("lists the verdict and reasons, exit 1 when risky", function()
      local lines, code = risk.report(diff("CLAUDE.md"))
      assert.are.same({ "risk:high", "- changes the guardrails: CLAUDE.md" }, lines)
      assert.are.equal(1, code)
    end)

    it("exits 0 when low risk", function()
      local lines, code = risk.report(diff("Logic.lua"))
      assert.are.same({ "risk:low" }, lines)
      assert.are.equal(0, code)
    end)
  end)

  describe("diffCommand", function()
    it("diffs from the merge base", function()
      local fixed = "git diff --no-color --no-ext-diff --src-prefix=a/ --dst-prefix=b/ -M "
      assert.are.equal(fixed .. "'main...HEAD'", risk.diffCommand("main"))
      assert.are.equal(fixed .. "'a...b'", risk.diffCommand("a", "b"))
    end)

    it("rejects option-like or quoted arguments", function()
      assert.is_nil(risk.diffCommand("--output=x"))
      assert.is_nil(risk.diffCommand("main", "-x"))
      assert.is_nil(risk.diffCommand("ma'in"))
    end)
  end)
end)
