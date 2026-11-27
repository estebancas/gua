local helpers = dofile("spec/helpers.lua")

describe("Logic", function()
  local Logic

  before_each(function()
    Logic = helpers.loadAddonFile("Logic.lua").Logic
  end)

  describe("mergeDefaults", function()
    it("fills in missing values", function()
      local db = Logic.mergeDefaults({}, { enabled = true, debug = false })
      assert.are.same({ enabled = true, debug = false }, db)
    end)

    it("keeps values the user already has", function()
      local db = Logic.mergeDefaults({ enabled = false }, { enabled = true })
      assert.is_false(db.enabled)
    end)

    it("merges nested tables", function()
      local db = Logic.mergeDefaults(
        { frame = { x = 10 } },
        { frame = { x = 0, y = 0 } }
      )
      assert.are.same({ x = 10, y = 0 }, db.frame)
    end)

    it("keeps keys that have no default", function()
      local db = Logic.mergeDefaults({ legacy = 1 }, { enabled = true })
      assert.are.equal(1, db.legacy)
    end)

    it("returns the target table itself", function()
      local target = {}
      assert.are.equal(target, Logic.mergeDefaults(target, { enabled = true }))
    end)

    it("replaces a non-table value where a table is expected", function()
      local db = Logic.mergeDefaults({ frame = "broken" }, { frame = { x = 0 } })
      assert.are.same({ x = 0 }, db.frame)
    end)
  end)

  describe("parseCommand", function()
    it("splits command and arguments", function()
      local command, rest = Logic.parseCommand("  Debug  on ")
      assert.are.equal("debug", command)
      assert.are.equal("on", rest)
    end)

    it("handles empty input", function()
      local command, rest = Logic.parseCommand("")
      assert.are.equal("", command)
      assert.are.equal("", rest)
    end)

    it("handles nil input", function()
      local command = Logic.parseCommand(nil)
      assert.are.equal("", command)
    end)
  end)
end)
