-- AI STAR CUBE · hyperlink rules for agent output
local wezterm = require("wezterm")

local M = {}

function M.apply(config)
  local rules = wezterm.default_hyperlink_rules()

  -- path/to/file.ext:line[:col]  (common in compiler / agent output)
  table.insert(rules, {
    regex = "\\b([\\w./\\\\-]+\\.[A-Za-z0-9]{1,8}):(\\d+)(?::(\\d+))?\\b",
    format = "$1:$2",
    highlight = 1,
  })

  -- Windows absolute paths → file URL (files AND folders in sidebar)
  -- Example: G:\GrokProject\WZ_Skill\docs
  table.insert(rules, {
    regex = "([A-Za-z]:\\\\(?:[^<>:\\\"/|?*\\r\\n]+\\\\)*[^<>:\\\"/|?*\\r\\n]*)",
    format = "file:///$1",
    highlight = 1,
  })

  -- Also match forward-slash Windows paths if any
  table.insert(rules, {
    regex = "([A-Za-z]:/(?:[^<>:\\\"|?*\\r\\n]+/)*[^<>:\\\"|?*\\r\\n]*)",
    format = "file:///$1",
    highlight = 1,
  })

  config.hyperlink_rules = rules
end

return M
