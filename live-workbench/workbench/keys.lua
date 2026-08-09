-- AI STAR CUBE · leader key, key tables, desktop accelerators
--
-- ═══════════════════════════════════════════════════════════════════════════
--  KEY POLICY (Chinese IME friendly + low conflict, 2026-08)
-- ═══════════════════════════════════════════════════════════════════════════
--
--  SCOPE (important):
--    WezTerm keybindings are WINDOW-LOCAL, not system-global.
--    They fire only while a WezTerm window is focused. No RegisterHotKey.
--    When another app is focused, Windows/Explorer/browser keep their F-keys.
--
--  1. Core chords NEVER require Shift / uppercase letters.
--     Chinese IME everyday state is lowercase; Shift costs mode switches
--     and Ctrl+Shift is often "switch language/IME" on CN Windows.
--
--  2. Leader = Alt+z then a single lowercase key (or digit / symbol).
--     Old Alt+; failed on many CN-Windows + IME setups (no LEADER flash).
--     NOT Ctrl+; — that chord is owned by Grok TUI (prompt queue).
--     Critical actions also have LEADER-free bindings (e.g. Ctrl+Shift+R reload).
--
--  3. One-shot direct = bare function keys chosen to avoid:
--       F1  Windows Help (often swallowed before the app)
--       F2  Grok TUI Settings (must pass through to the PTY)
--       F5  browser/IDE refresh muscle memory
--       F10 menu focus on some Win32 hosts
--       F12 devtools muscle memory
--     Map: F7 explorer · F9 projects · F4 close pane · F6 desk · F8 help
--
--  4. Dropped (mouse is enough): pane focus h/j/k/l, pane swap, resize mode.
--
--  5. Industry defaults we leave alone (not taught as workbench core):
--     Ctrl+Shift+C/V, Ctrl+Shift+T/W, Ctrl+Shift+Arrow, etc.
-- ═══════════════════════════════════════════════════════════════════════════

local wezterm = require("wezterm")
local act = wezterm.action
local layouts = require("workbench.layouts")
local launch = require("workbench.launch")
local projects = require("workbench.projects")
local help = require("workbench.help")
local status = require("workbench.status")
local resume = require("workbench.resume")

local M = {}

local function cb(fn)
  return wezterm.action_callback(fn)
end

function M.apply(config)
  ------------------------------------------------------------------
  -- Leader: Alt+z  (window-local; does not steal Grok's Ctrl+;)
  -- Why not Alt+; ? On CN Windows + IME, Alt+; often never enters LEADER
  -- (status bar never flashes LEADER; follow-up keys do nothing).
  ------------------------------------------------------------------
  config.leader = {
    key = "z",
    mods = "ALT",
    timeout_milliseconds = 3000,
  }
  config.disable_default_key_bindings = false

  -- Prefer left-Alt as a real modifier (not compose)
  config.send_composed_key_when_left_alt_is_pressed = false
  config.send_composed_key_when_right_alt_is_pressed = true

  -- Notify when reload actually applied (so user knows it worked)
  wezterm.on("window-config-reloaded", function(window, pane)
    pcall(function()
      local gen = tostring(wezterm.GLOBAL.star_cube_status_gen or "?")
      window:toast_notification(
        "AI STAR CUBE",
        "配置已重载 · status-gen="
          .. gen
          .. " · 若路径槽仍粘页签请【完全退出 WezTerm 再开】· Ctrl+Shift+R",
        nil,
        6000
      )
    end)
  end)

  config.keys = {
    ------------------------------------------------------------------
    -- DIRECT — function keys (workbench only; free Grok F2)
    ------------------------------------------------------------------
    { key = "F7", mods = "NONE", action = cb(projects.open_sidebar) },
    -- F9: project picker (fast list). If your keyboard needs Fn, try Fn+F9
    --    or use Leader Alt+z then .
    { key = "F9", mods = "NONE", action = cb(projects.show_picker) },
    { key = "F4", mods = "NONE", action = act.CloseCurrentPane({ confirm = true }) },
    { key = "F6", mods = "NONE", action = cb(layouts.open_workbench_fresh) },
    -- F3: resume hub — continue conversations / recent projects after restart
    { key = "F3", mods = "NONE", action = cb(resume.show_hub) },
    -- Ctrl+F3: continue latest session for THIS tab's project only
    { key = "F3", mods = "CTRL", action = cb(resume.continue_current) },
    { key = "F8", mods = "NONE", action = cb(help.toggle) },
    { key = "F11", mods = "NONE", action = act.ToggleFullScreen },

    ------------------------------------------------------------------
    -- RELOAD — must NOT depend on Leader (Alt+; was dead on CN IME)
    -- Note: LEADER+r is Review layout — do not steal it for reload.
    ------------------------------------------------------------------
    { key = "r", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
    { key = "R", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
    { key = "r", mods = "CTRL|ALT", action = act.ReloadConfiguration },
    { key = "R", mods = "CTRL|ALT", action = act.ReloadConfiguration },
    -- Extra obvious binding (no Shift required)
    { key = "F5", mods = "CTRL", action = act.ReloadConfiguration },

    ------------------------------------------------------------------
    -- Explicitly DO NOT bind F1 / F2 / F5 / F10 / F12
    -- so OS Help, Grok Settings, refresh, menu, devtools stay usable.
    ------------------------------------------------------------------

    ------------------------------------------------------------------
    -- Command surfaces  (Leader + lowercase / symbol only)
    ------------------------------------------------------------------
    { key = "p", mods = "LEADER", action = act.ActivateCommandPalette },
    { key = "m", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|LAUNCH_MENU_ITEMS" }) },
    { key = "/", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|KEY_ASSIGNMENTS" }) },
    {
      key = "`",
      mods = "LEADER",
      action = act.ShowLauncherArgs({
        flags = "FUZZY|LAUNCH_MENU_ITEMS|WORKSPACES|TABS|DOMAINS|COMMANDS",
      }),
    },

    ------------------------------------------------------------------
    -- AI layouts
    ------------------------------------------------------------------
    { key = "a", mods = "LEADER", action = cb(layouts.open_workbench_fresh) },
    { key = "b", mods = "LEADER", action = cb(layouts.open_workbench) },
    { key = "d", mods = "LEADER", action = cb(layouts.open_dual_ai) },
    { key = "r", mods = "LEADER", action = cb(layouts.open_review) },
    { key = "g", mods = "LEADER", action = cb(layouts.open_focus_grok) },
    { key = "c", mods = "LEADER", action = cb(layouts.open_focus_codex) },
    -- Resume / continue (same as F3 / Ctrl+F3)
    { key = "l", mods = "LEADER", action = cb(resume.show_hub) },
    { key = "c", mods = "LEADER|SHIFT", action = cb(resume.continue_current) },

    ------------------------------------------------------------------
    -- Panes — focus with mouse
    -- Splits must NOT inherit bootstrap default_prog (would open init panel
    -- in a tiny pane). Always spawn plain PowerShell in splits.
    ------------------------------------------------------------------
    {
      key = "v",
      mods = "LEADER",
      action = act.SplitHorizontal({
        domain = "CurrentPaneDomain",
        args = launch.powershell,
      }),
    },
    {
      key = "s",
      mods = "LEADER",
      action = act.SplitVertical({
        domain = "CurrentPaneDomain",
        args = launch.powershell,
      }),
    },
    { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
    { key = "o", mods = "LEADER", action = act.PaneSelect({ alphabet = "asdfghjkl", mode = "Activate" }) },

    ------------------------------------------------------------------
    -- Tabs — new tab = task init panel (same as cold start / + button)
    ------------------------------------------------------------------
    {
      key = "t",
      mods = "LEADER",
      action = act.SpawnCommandInNewTab({
        args = launch.bootstrap_args(),
        cwd = launch.home,
      }),
    },
    -- Override WezTerm default Ctrl+Shift+T → init panel (not bare PS)
    {
      key = "t",
      mods = "CTRL|SHIFT",
      action = act.SpawnCommandInNewTab({
        args = launch.bootstrap_args(),
        cwd = launch.home,
      }),
    },
    -- Plain PowerShell tab (escape hatch): Ctrl+Alt+T
    {
      key = "t",
      mods = "CTRL|ALT",
      action = act.SpawnCommandInNewTab({
        args = launch.powershell,
        cwd = launch.home,
      }),
    },
    { key = "w", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
    { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
    { key = "[", mods = "LEADER", action = act.ActivateTabRelative(-1) },
    { key = "1", mods = "LEADER", action = act.ActivateTab(0) },
    { key = "2", mods = "LEADER", action = act.ActivateTab(1) },
    { key = "3", mods = "LEADER", action = act.ActivateTab(2) },
    { key = "4", mods = "LEADER", action = act.ActivateTab(3) },
    { key = "5", mods = "LEADER", action = act.ActivateTab(4) },
    { key = "6", mods = "LEADER", action = act.ActivateTab(5) },
    { key = "7", mods = "LEADER", action = act.ActivateTab(6) },
    { key = "8", mods = "LEADER", action = act.ActivateTab(7) },
    { key = "9", mods = "LEADER", action = act.ActivateTab(-1) },

    ------------------------------------------------------------------
    -- Explorer / projects / help
    ------------------------------------------------------------------
    { key = "e", mods = "LEADER", action = cb(projects.open_sidebar) },
    -- . = project pick (same as F9); j = jump already-open workspaces
    { key = ".", mods = "LEADER", action = cb(projects.show_picker) },
    { key = ",", mods = "LEADER", action = cb(projects.show_workbench_picker) },
    { key = "j", mods = "LEADER", action = cb(projects.show_workspace_switcher) },
    { key = "h", mods = "LEADER", action = cb(help.toggle) },
    -- Toggle per-tab task HUD on status bar (Shift+h after Leader)
    { key = "h", mods = "LEADER|SHIFT", action = cb(status.toggle_hud) },

    ------------------------------------------------------------------
    -- Workspaces
    ------------------------------------------------------------------
    {
      key = "u",
      mods = "LEADER",
      action = act.PromptInputLine({
        description = "New / switch workspace name",
        action = cb(function(window, pane, line)
          if line and #line > 0 then
            window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
          end
        end),
      }),
    },

    ------------------------------------------------------------------
    -- Harvest AI output
    ------------------------------------------------------------------
    { key = "f", mods = "LEADER", action = act.Search({ CaseInSensitiveString = "" }) },
    { key = "y", mods = "LEADER", action = act.QuickSelect },
    { key = "k", mods = "LEADER", action = act.ActivateCopyMode },

    ------------------------------------------------------------------
    -- Font / window / meta (window-local only)
    ------------------------------------------------------------------
    { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
    { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
    { key = "0", mods = "CTRL", action = act.ResetFontSize },
    { key = "Enter", mods = "LEADER", action = act.ToggleFullScreen },
    -- Reload via leader (Alt+z then '). LEADER+r stays Review — do not override.
    { key = "'", mods = "LEADER", action = act.ReloadConfiguration },
    { key = "i", mods = "LEADER", action = act.ShowDebugOverlay },
    {
      key = "\\",
      mods = "LEADER",
      action = act.SpawnCommandInNewTab({ args = launch.powershell }),
    },

    -- Legacy: Alt+; used to be Leader but often dead on CN IME.
    -- Map it to a short key-table so old muscle memory still reloads / helps.
    {
      key = ";",
      mods = "ALT",
      action = act.ActivateKeyTable({
        name = "legacy_leader",
        one_shot = true,
        timeout_milliseconds = 3000,
      }),
    },
    {
      key = "phys:Semicolon",
      mods = "ALT",
      action = act.ActivateKeyTable({
        name = "legacy_leader",
        one_shot = true,
        timeout_milliseconds = 3000,
      }),
    },
  }

  config.key_tables = config.key_tables or {}
  config.key_tables.legacy_leader = {
    { key = "r", action = act.ReloadConfiguration },
    { key = "R", action = act.ReloadConfiguration },
    { key = "'", action = act.ReloadConfiguration },
    { key = "h", action = cb(help.toggle) },
    { key = "e", action = cb(projects.open_sidebar) },
    { key = ".", action = cb(projects.show_picker) },
    { key = "Escape", action = act.PopKeyTable },
  }

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
    "\\b[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}\\b",
  }
end

return M
