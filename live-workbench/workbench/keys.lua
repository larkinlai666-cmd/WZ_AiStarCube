-- AI STAR CUBE · slim F-key workbench (no Leader)
--
-- Core map (single keys only; mouse for Init via +):
--   F2  unbound — 留给 AI agent 自身（设置/快捷键）
--   F3  NEW local project wizard (name → parent choice → freeze → open)
--   F4  close pane
--   F5  reload WezTerm config
--   F6  3-pane AI desk
--   F7  Explorer sidebar
--   F1  optional cheatsheet (may be swallowed by Windows Help)
--
-- Not bound: F8/F9 continue/picker, Leader, Ctrl+Shift+T teaching.
-- Init list = click + (default_prog) or cold start.
--
local wezterm = require("wezterm")
local act = wezterm.action
local layouts = require("workbench.layouts")
local projects = require("workbench.projects")
local help = require("workbench.help")
local resume = require("workbench.resume")

local M = {}

local function cb(fn)
  return wezterm.action_callback(fn)
end

function M.apply(config)
  -- No Leader chord layer (user: no expectation to use Alt+z combos)
  config.leader = nil
  config.disable_default_key_bindings = false

  config.send_composed_key_when_left_alt_is_pressed = false
  config.send_composed_key_when_right_alt_is_pressed = true

  wezterm.on("window-config-reloaded", function(window, pane)
    pcall(function()
      window:toast_notification(
        "AI STAR CUBE",
        "配置已重载 · F3新建 · F5重载 · F6桌 · F7文件 · F4关窗格",
        nil,
        5000
      )
    end)
  end)

  config.keys = {
    ------------------------------------------------------------------
    -- F1–F7 workbench (F2 free for AI agents)
    ------------------------------------------------------------------
    { key = "F1", mods = "NONE", action = cb(help.toggle) },
    -- F2 intentionally unbound (留给 AI agent 自身)
    { key = "F3", mods = "NONE", action = cb(resume.show_new_project) },
    { key = "F4", mods = "NONE", action = act.CloseCurrentPane({ confirm = true }) },
    { key = "F5", mods = "NONE", action = act.ReloadConfiguration },
    { key = "F6", mods = "NONE", action = cb(layouts.open_workbench_fresh) },
    { key = "F7", mods = "NONE", action = cb(projects.open_sidebar) },

    ------------------------------------------------------------------
    -- Keep one chord reload as emergency if F5 blocked by OS/Fn
    ------------------------------------------------------------------
    { key = "r", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
    { key = "R", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
  }

  -- Preserve copy/search mode tables if available
  local ok, defaults = pcall(function()
    return wezterm.gui.default_key_tables()
  end)
  if ok and defaults then
    config.key_tables = config.key_tables or {}
    config.key_tables.copy_mode = defaults.copy_mode
    config.key_tables.search_mode = defaults.search_mode
  end

  config.quick_select_alphabet = "qwertyuiopasdfghjklzxcvbnm0123456789"
  config.quick_select_patterns = {
    "https?://[\\w\\-._~:/?#\\[\\]@!$&'()*+,;=%]+",
    "[A-Za-z]:\\\\(?:[^\\s|<>\"*?]+\\\\)*[^\\s|<>\"*?]+",
    "(?:/[\\w.-]+)+/?",
    "[\\w./\\\\-]+\\.[A-Za-z0-9]{1,8}:\\d+(?::\\d+)?",
    "\\b[0-9a-f]{7,40}\\b",
  }
end

return M
