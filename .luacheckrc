std = "lua51"
max_line_length = false
exclude_files = { ".lua/", "Libs/", ".release/" }

-- Globals this addon creates.
globals = {
  "GUADB",
  "SLASH_GUA1",
  "SlashCmdList",
}

-- WoW API used by this addon. Add new API names here as you use them.
read_globals = {
  "C_AddOns",
  "CreateFrame",
}

files["spec/"] = { std = "+busted" }
