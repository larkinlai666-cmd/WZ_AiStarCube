-- =============================================================================
--  AI STAR CUBE for WezTerm
--  Professional multi-pane desk for dynamically discovered CLI AI agents
--
--  Chinese-IME friendly: no Shift/uppercase for core workbench keys
--  Direct: F1 help · F3 new project · F4 close pane · F5 reload · F6 desk · F7 explorer
--  No Leader layer; F2 and F9–F12 remain available to Agent CLIs.
--  F8 = absolute escape pod (does not run Init).
--  Reload: Ctrl+Shift+R  (does not need Leader)
--  Scope: window-local only (WezTerm focused); never system-global
--
--  LOAD-TIME SAFETY (do not regress):
--    - Config evaluation must NEVER call wezterm.run_child_process / yield.
--      Symptom: "attempt to yield across a C-call boundary" → WezTerm drops
--      the whole config and shows a stock default (all personalization gone).
--    - Module requires are soft-failed so one broken file cannot wipe chrome.
--    - package.loaded for workbench.* is cleared so reloads pick up new code.
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

local config = wezterm.config_builder and wezterm.config_builder() or {}

-- Minimal always-on baseline if workbench modules partially fail
config.color_scheme = config.color_scheme or "Catppuccin Mocha"
config.check_for_updates = false
config.automatically_reload_config = true
config.bold_brightens_ansi_colors = "BrightAndBold"

local load_errors = {}

local function safe_require(name)
  local ok, mod = pcall(require, name)
  if not ok then
    table.insert(load_errors, name .. ": " .. tostring(mod))
    pcall(function()
      wezterm.log_error("[AI STAR CUBE] require failed: " .. name .. " → " .. tostring(mod))
    end)
    return nil
  end
  return mod
end

local function safe_apply(label, mod)
  if not mod or type(mod.apply) ~= "function" then
    table.insert(load_errors, label .. ": missing apply()")
    return
  end
  local ok, err = pcall(mod.apply, config)
  if not ok then
    table.insert(load_errors, label .. ".apply: " .. tostring(err))
    pcall(function()
      wezterm.log_error("[AI STAR CUBE] apply failed: " .. label .. " → " .. tostring(err))
    end)
  end
end

-- Load order: options (chrome) → launch (paths) → keys → status → hyperlinks
safe_apply("options", safe_require("workbench.options"))
safe_apply("launch", safe_require("workbench.launch"))
safe_apply("keys", safe_require("workbench.keys"))
safe_apply("status", safe_require("workbench.status"))
safe_apply("hyperlinks", safe_require("workbench.hyperlinks"))

-- F8 escape pod: registered AFTER keys.lua (which replaces config.keys).
-- Must not require bootstrap.ps1, discovery, keys.lua, or layouts.lua.
do
  local act = wezterm.action
  local cfg = config_dir or ((wezterm.home_dir or "") .. "\\.config\\wezterm")
  local pod = cfg .. "\\workbench\\escape-pod.ps1"
  local args
  local f = io.open(pod, "r")
  if f then
    f:close()
    args = {
      "powershell.exe",
      "-NoLogo",
      "-NoProfile",
      "-NoExit",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      pod,
    }
  else
    args = {
      "powershell.exe",
      "-NoLogo",
      "-NoProfile",
      "-NoExit",
      "-Command",
      "Write-Host 'escape-pod.ps1 missing. Run workbench\\Escape-WZ.cmd or reinstall.' -ForegroundColor Yellow",
    }
  end
  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = "F8",
    mods = "NONE",
    action = act.SpawnCommandInNewTab({
      args = args,
      -- workbench dir always exists; pod creates repair\ itself
      cwd = cfg .. "\\workbench",
    }),
  })
end

if #load_errors > 0 then
  -- Surface once after GUI is up (toast needs a window; use window-config-reloaded)
  wezterm.GLOBAL = wezterm.GLOBAL or {}
  wezterm.GLOBAL.star_cube_load_errors = load_errors
  wezterm.on("gui-attached", function()
    pcall(function()
      local msg = table.concat(load_errors, " | ")
      if #msg > 140 then
        msg = msg:sub(1, 137) .. "..."
      end
      pcall(function()
        local f = io.open((config_dir or ((wezterm.home_dir or "") .. "\\.config\\wezterm")) .. "\\workbench\\last-load-errors.txt", "w")
        if f then
          f:write(os.date("!%Y-%m-%dT%H:%M:%SZ") .. "\n")
          f:write(table.concat(load_errors, "\n"))
          f:close()
        end
      end)
      for _, gui in ipairs(wezterm.gui.gui_windows() or {}) do
        gui:toast_notification("WZ 模块告警 · 按 F8 进逃生舱", msg .. "  · F8 = repair", nil, 9000)
      end
    end)
  end)
end

return config

-- reload-bump: 2026-08-09T15:50:00-agent-parity
