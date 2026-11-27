-- Specs for scripts/check-pr-title.lua (issue #58).
local title = dofile("scripts/check-pr-title.lua")

local function rejects(text, expected)
  local ok, reason = title.check(text)
  assert.is_false(ok)
  assert.truthy(reason:find(expected, 1, true), "expected '" .. expected .. "' in: " .. reason)
end

describe("check-pr-title", function()
  it("accepts every type with its emoji", function()
    for _, t in ipairs(title.TYPES) do
      assert.is_true(title.check(t.emoji .. " " .. t.type .. ": do a thing"))
    end
  end)

  it("accepts ♻️ and ⚡️ with or without the variation selector", function()
    assert.is_true(title.check("♻ ref: split the core file"))
    assert.is_true(title.check("⚡ perf: cache the lookup"))
    assert.is_true(title.check("♻️ ref: split the core file"))
  end)

  it("accepts GitHub's revert titles", function()
    assert.is_true(title.check('Revert "🚀 feat: add login"'))
  end)

  it("rejects a plain sentence", function()
    rejects("Label PRs red or green by risk in CI", "must start with")
  end)

  it("rejects a type without its emoji, or the wrong emoji", function()
    rejects("feat: add login", "must start with")
    rejects("🐛 feat: add login", "must start with")
    rejects("🚀 feature: add login", "must start with")
    rejects("🚀 feat add login", "must start with")
  end)

  it("rejects an empty title or subject", function()
    rejects(nil, "title is empty")
    rejects("   ", "title is empty")
    rejects("🚀 feat: ", "subject is empty")
  end)

  it("counts the subject in characters, not bytes", function()
    assert.is_true(title.check("🚀 feat: " .. string.rep("é", 45)))
    rejects("🚀 feat: " .. string.rep("a", 46), "subject is 46 characters")
  end)

  it("main returns 0 for a good title and 1 for a bad one", function()
    local out = {}
    local function write(s)
      out[#out + 1] = s
    end
    local good = title.main("🧪 test: cover the title check", write)
    local bad = title.main("no format", write)
    assert.are.equal(0, good)
    assert.are.equal(1, bad)
    assert.truthy(out[2]:find("🔧 chore", 1, true))
  end)
end)
