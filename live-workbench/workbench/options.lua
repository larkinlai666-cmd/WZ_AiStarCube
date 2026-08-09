-- AI STAR CUBE · appearance, window chrome, scrollback, mouse
local wezterm = require("wezterm")

local M = {}

function M.apply(config)
  ------------------------------------------------------------------
  -- Window chrome (desktop-app feel)
  ------------------------------------------------------------------
  config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
  config.window_background_opacity = 0.97
  config.win32_system_backdrop = "Acrylic" -- Windows blur; safe no-op if unsupported
  config.initial_cols = 140
  config.initial_rows = 40
  config.window_padding = {
    left = 8,
    right = 8,
    top = 6,
    bottom = 6,
  }
  config.window_close_confirmation = "NeverPrompt"
  config.adjust_window_size_when_changing_font_size = false
  config.warn_about_missing_glyphs = false

  ------------------------------------------------------------------
  -- Tabs / top nav bar
  -- WezTerm has no drag-to-resize for the bar; size is config-driven:
  --   vertical  → window_frame.font_size (fancy tab bar height follows font)
  --   horizontal → tab_max_width + status text padding in status.lua
  --
  -- TAB-FIRST POLICY (fix stacked windows):
  --   Second wezterm launches used to create a NEW maximized OS window.
  --   That window covered the first one; only after closing it did the
  --   previous session reappear — tabs never sat side-by-side.
  --   prefer_to_spawn_tabs routes new launches into tabs of the existing GUI.
  ------------------------------------------------------------------
  config.use_fancy_tab_bar = true
  config.tab_bar_at_bottom = false
  config.hide_tab_bar_if_only_one_tab = false
  config.show_new_tab_button_in_tab_bar = true
  -- Titles: 「项目 · 工具」; keep tabs compact so brand+path own more of the bar
  config.show_tab_index_in_tab_bar = false
  -- Keep tabs compact; brand + fixed path own most of the title bar
  config.tab_max_width = 20
  config.switch_to_last_active_tab_when_closing_tab = true
  config.tab_and_split_indices_are_zero_based = false
  config.prefer_to_spawn_tabs = true

  config.window_frame = {
    font = wezterm.font({ family = "Segoe UI", weight = "Bold" }),
    font_size = 11.0,
    active_titlebar_bg = "#11111b",
    inactive_titlebar_bg = "#11111b",
  }

  ------------------------------------------------------------------
  -- Fonts (fallback chain for this machine)
  ------------------------------------------------------------------
  config.font = wezterm.font_with_fallback({
    { family = "Consolas", weight = "Regular" },
    { family = "Segoe UI Emoji" },
    { family = "Segoe UI Symbol" },
    { family = "Microsoft YaHei UI" },
  })
  config.font_size = 12.0
  config.line_height = 1.08
  config.cell_width = 1.0
  config.freetype_load_target = "Light"
  config.freetype_render_target = "HorizontalLcd"
  config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }

  ------------------------------------------------------------------
  -- Colors
  ------------------------------------------------------------------
  config.color_scheme = "Catppuccin Mocha"
  config.inactive_pane_hsb = {
    saturation = 0.75,
    brightness = 0.55,
  }
  -- Catppuccin Mocha roles (match status.lua):
  --   brand Yellow #f9e2af | path Peach #fab387 | active tab Blue #89b4fa | off Mantle #1e1e2e
  config.colors = {
    tab_bar = {
      background = "#11111b",
      active_tab = {
        bg_color = "#89b4fa", -- Blue (tabs only; path uses Peach in status.lua)
        fg_color = "#11111b",
        intensity = "Bold",
      },
      inactive_tab = {
        bg_color = "#1e1e2e",
        fg_color = "#a6adc8",
      },
      inactive_tab_hover = {
        bg_color = "#45475a",
        fg_color = "#cdd6f4",
      },
      new_tab = {
        bg_color = "#11111b",
        fg_color = "#6c7086",
      },
      new_tab_hover = {
        bg_color = "#313244",
        fg_color = "#89b4fa",
      },
    },
    split = "#45475a",
  }

  ------------------------------------------------------------------
  -- Scrollback / selection (critical for long AI output)
  ------------------------------------------------------------------
  config.scrollback_lines = 100000
  config.enable_scroll_bar = true
  config.min_scroll_bar_height = "2cell"
  config.selection_word_boundary = " \t\n{}[]()\"'`,;:│┃┆┇┊┋<>|"

  ------------------------------------------------------------------
  -- Cursor & bell
  ------------------------------------------------------------------
  config.default_cursor_style = "BlinkingBar"
  config.cursor_blink_rate = 500
  config.cursor_thickness = "1.5px"
  config.visual_bell = {
    fade_in_function = "EaseIn",
    fade_in_duration_ms = 80,
    fade_out_function = "EaseOut",
    fade_out_duration_ms = 120,
  }
  config.audible_bell = "Disabled"

  ------------------------------------------------------------------
  -- Input / terminal capability (Grok TUI friendly)
  ------------------------------------------------------------------
  config.term = "xterm-256color"
  config.enable_kitty_keyboard = true
  config.enable_csi_u_key_encoding = false
  config.allow_win32_input_mode = true
  config.use_ime = true
  config.ime_preedit_rendering = "Builtin"

  ------------------------------------------------------------------
  -- Mouse
  ------------------------------------------------------------------
  config.hide_mouse_cursor_when_typing = true
  config.pane_focus_follows_mouse = false
  -- false: first click on a hyperlink can open it (not wasted only on focus)
  config.swallow_mouse_click_on_pane_focus = false
  config.swallow_mouse_click_on_window_focus = true

  config.mouse_bindings = {
    -- Plain click: finish selection only — do NOT open hyperlinks.
    -- Accidental clicks on path text (wizard / agent logs) were opening
    -- wrong apps (e.g. .cmd / trust-directory prompts). Intentional open:
    -- Ctrl+Click or Middle-Click.
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "NONE",
      action = wezterm.action.CompleteSelection("Clipboard"),
    },
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "CTRL",
      action = wezterm.action.OpenLinkAtMouseCursor,
    },
    {
      event = { Up = { streak = 1, button = "Middle" } },
      mods = "NONE",
      action = wezterm.action.OpenLinkAtMouseCursor,
    },
    {
      event = { Up = { streak = 1, button = "Right" } },
      mods = "NONE",
      action = wezterm.action.PasteFrom("Clipboard"),
    },
    {
      event = { Down = { streak = 3, button = "Left" } },
      action = wezterm.action.SelectTextAtMouseCursor("Line"),
      mods = "NONE",
    },
  }

  ------------------------------------------------------------------
  -- Shell / new-tab default
  -- New tab (+ button, Ctrl+Shift+T, prefer_to_spawn_tabs) uses default_prog.
  -- Default = WZ task init panel (bootstrap.ps1), not bare PowerShell.
  -- Opt-out: create empty file workbench/no-bootstrap
  -- Plain shell: Leader Alt+z then \   or launch menu "PowerShell"
  ------------------------------------------------------------------
  local launch = require("workbench.launch")
  config.default_prog = launch.default_prog()
  config.default_cwd = wezterm.home_dir
  config.default_workspace = "home"

  ------------------------------------------------------------------
  -- Performance
  ------------------------------------------------------------------
  config.max_fps = 120
  config.animation_fps = 60
  config.front_end = "WebGpu"
  config.webgpu_power_preference = "HighPerformance"
end

return M
