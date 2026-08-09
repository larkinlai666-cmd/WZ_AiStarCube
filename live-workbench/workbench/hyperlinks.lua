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

  -- Windows absolute paths → file URL (folders / source files).
  -- Prefer non-launcher extensions so .exe/.cmd/.ps1 do not become links
  -- (clicking them caused wrong app / "trust directory" noise).
  table.insert(rules, {
    regex = "([A-Za-z]:\\\\(?:[^<>:\\\"/|?*\\r\\n]+\\\\)*[^<>:\\\"/|?*\\r\\n]+\\.(?:md|txt|rs|ts|tsx|js|jsx|json|lua|py|toml|ya?ml|go|java|cs|cpp|h|hpp|css|html|ps1m?|log|csv))",
    format = "file:///$1",
    highlight = 1,
  })

  -- Project folders (no file extension): path ending without a trailing slash is ok
  table.insert(rules, {
    regex = "([A-Za-z]:\\\\(?:[^<>:\\\"/|?*\\r\\n.]+\\\\)+[^<>:\\\"/|?*\\r\\n.]+)",
    format = "file:///$1",
    highlight = 1,
  })

  config.hyperlink_rules = rules
end

return M
