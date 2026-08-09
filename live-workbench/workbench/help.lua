-- AI STAR CUBE · toggleable shortcuts cheatsheet (F8 / Leader+h)
--
-- Window-local only (WezTerm focused). F1 avoided (OS Help).
local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

-- Always resolve under %USERPROFILE%\.config\wezterm (not dirname of config_file:
-- entry point is often ~/.wezterm.lua which only dofile()s the real config).
local function workbench_dir()
  local home = wezterm.home_dir
  if not home or home == "" then
    home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
  end
  home = home:gsub("/", "\\"):gsub("\\+$", "")
  return home .. "\\.config\\wezterm\\workbench"
end

local function is_cheatsheet_pane(pane)
  if not pane then
    return false
  end

  local ok_vars, user_vars = pcall(function()
    return pane:get_user_vars()
  end)
  if ok_vars and user_vars then
    local v = user_vars.star_cube_help
    if v == "1" or v == 1 or v == true then
      return true
    end
  end

  local title = ""
  pcall(function()
    title = tostring(pane:get_title() or "")
  end)
  if title:lower():find("cheatsheet", 1, true) then
    return true
  end

  local ok_info, info = pcall(function()
    return pane:get_foreground_process_name()
  end)
  if ok_info and info then
    local s = tostring(info):lower()
    if s:find("cheatsheet", 1, true) then
      return true
    end
  end

  return false
end

local function find_cheatsheet_pane(window)
  local ok, mux_win = pcall(function()
    return window:mux_window()
  end)
  if not ok or not mux_win then
    return nil
  end

  local ok_tabs, tabs = pcall(function()
    return mux_win:tabs_with_info()
  end)
  if not ok_tabs or not tabs then
    return nil
  end

  for _, tab_info in ipairs(tabs) do
    local tab = tab_info.tab
    local ok_panes, panes = pcall(function()
      return tab:panes_with_info()
    end)
    if ok_panes and panes then
      for _, pane_info in ipairs(panes) do
        if is_cheatsheet_pane(pane_info.pane) then
          return pane_info.pane
        end
      end
    end
  end
  return nil
end

local function toast(window, title, msg, ms)
  pcall(function()
    window:toast_notification(title, msg, nil, ms or 2500)
  end)
end

--- Toggle: open right-side cheatsheet, or close if already open
function M.toggle(window, pane)
  local existing = find_cheatsheet_pane(window)
  if existing then
    pcall(function()
      existing:activate()
    end)
    pcall(function()
      window:perform_action(act.CloseCurrentPane({ confirm = false }), existing)
    end)
    toast(window, "AI STAR CUBE", "快捷键面板已关闭", 1800)
    return
  end

  local dir = workbench_dir()
  local ps1 = dir .. "\\cheatsheet.ps1"

  -- Verify script exists before split (clearer than a dead pane)
  local exists = false
  pcall(function()
    local f = io.open(ps1, "r")
    if f then
      f:close()
      exists = true
    end
  end)
  if not exists then
    toast(window, "AI STAR CUBE", "找不到 cheatsheet.ps1: " .. ps1, 4500)
    return
  end

  local ok_split, side = pcall(function()
    return pane:split({
      direction = "Right",
      size = 0.38,
      args = {
        "powershell.exe",
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ps1,
      },
      cwd = dir,
    })
  end)

  if not ok_split or not side then
    toast(
      window,
      "AI STAR CUBE",
      "打开速查失败: " .. tostring(side or "split nil"),
      4000
    )
    return
  end

  pcall(function()
    side:activate()
  end)
  toast(
    window,
    "AI STAR CUBE",
    "快捷键面板 · F8 或 Alt+; h 关闭 · 面板内 q",
    2800
  )
end

return M
