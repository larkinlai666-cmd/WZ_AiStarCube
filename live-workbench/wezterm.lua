-- =============================================================================
--  AI STAR CUBE for WezTerm
--  Professional multi-pane desk for Grok / Codex and other CLI AI tools
--
--  Chinese-IME friendly: no Shift/uppercase for core workbench keys
--  Direct: F7 explorer 路 F9 projects 路 F4 close pane 路 F6 desk 路 F8 help
--  Leader: Alt+z then lowercase (Alt+; flaky on CN IME; NOT Ctrl+; 鈥?Grok)
--  Reload: Ctrl+Shift+R  (does not need Leader)
--  Scope: window-local only (WezTerm focused); never system-global
--  Pane focus: mouse click (not bound)

-- =============================================================================

local wezterm = require("wezterm")

-- Ensure this config directory is on the module path (Windows-safe)
local config_dir = wezterm.config_file:match("(.*)[/\\][^/\\]+$")
if config_dir then
  package.path = config_dir
    .. "/?.lua;"
    .. config_dir
    .. "/?/init.lua;"
    .. package.path
end

-- CRITICAL: config reload keeps the same Lua package cache unless cleared.
-- Without this, require("workbench.status") returns the OLD module forever
-- while wezterm.on handlers keep stacking — classic "I fixed it but UI stuck".
do
  local doomed = {}
  for k in pairs(package.loaded) do
    if type(k) == "string" and (k == "workbench" or k:match("^workbench%.")) then
      table.insert(doomed, k)
    end
  end
  for _, k in ipairs(doomed) do
    package.loaded[k] = nil
  end
end

local options = require("workbench.options")
local launch = require("workbench.launch")
local keys = require("workbench.keys")
local status = require("workbench.status")
local hyperlinks = require("workbench.hyperlinks")

local config = wezterm.config_builder and wezterm.config_builder() or {}

options.apply(config)
launch.apply(config)
keys.apply(config)
status.apply(config)
hyperlinks.apply(config)

-- Optional: slightly denser UI for agent logs
config.bold_brightens_ansi_colors = "BrightAndBold"
-- Auto-reload only watches THIS file, not workbench/*.lua modules.
-- After editing modules: Ctrl+Shift+R  or touch this file / bump reload-bump below.
config.automatically_reload_config = true
config.check_for_updates = false

return config

-- reload-bump: 2026-08-08T20:15:00-path-cellwidth-handler-gen
