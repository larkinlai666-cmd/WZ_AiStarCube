-- AI STAR CUBE · resume / bootstrap front door
-- F3 and cold-start both open the tabular bootstrap panel (bootstrap.ps1).
local wezterm = require("wezterm")
local desk = require("workbench.desk")
local launch = require("workbench.launch")

local M = {}

local home = wezterm.home_dir

local function toast(window, title, msg, ms)
  pcall(function()
    window:toast_notification(title, msg, nil, ms or 3500)
  end)
end

function M.bootstrap_args()
  return launch.bootstrap_args()
end

--- Open the table init panel in a new tab (or current if requested)
function M.show_hub(window, pane)
  local mux_window = window:mux_window()
  local tab, main = mux_window:spawn_tab({
    args = M.bootstrap_args(),
    cwd = home,
  })
  if main then
    main:activate()
  end
  if tab then
    tab:set_title("Init")
  end
  toast(window, "任务初始化面板", "Enter续聊 · c新建向导 · n同项目新开 · a更松列表", 4500)
end

--- Continue latest session for current tab project (fast path)
function M.continue_current(window, pane)
  local name, root = desk.resolve_tab_task(window, pane)
  if not desk.is_strong_path(root) then
    toast(window, "继续对话", "当前页签无可靠项目路径 → 打开初始化面板", 4000)
    M.show_hub(window, pane)
    return
  end
  local args = launch.grok_continue_args(root)
  local mux_window = window:mux_window()
  local tab, main = mux_window:spawn_tab({
    args = args,
    cwd = root,
  })
  local pname = desk.project_label(root)
  if tab then
    tab:set_title("↩ " .. pname)
  end
  if main then
    main:activate()
    if not desk.bind_tab(tab, root, main) then
      desk.set_tab_desk(window, main, root)
    end
    if not desk.is_reserved_name(pname) then
      desk.set_root(pname, root)
    end
  end
  toast(window, "继续对话", "grok -c · " .. pname .. " · " .. desk.short_path(root, 36), 3500)
end

--- Used by gui-startup: should first window be the bootstrap panel?
function M.should_bootstrap_on_startup(cmd)
  -- If user passed an explicit program (e.g. grok --cwd …), respect it
  if cmd and cmd.args and #cmd.args > 0 then
    local a0 = tostring(cmd.args[1] or ""):lower()
    if a0:find("bootstrap.ps1", 1, true) then
      return false -- already bootstrapping
    end
    if a0:find("grok", 1, true) or a0:find("codex", 1, true) then
      return false
    end
    -- bare powershell / pwsh without our panel → still show bootstrap as home
  end
  -- Opt-out: create empty file ~/.config/wezterm/workbench/no-bootstrap
  local flag = home .. "\\.config\\wezterm\\workbench\\no-bootstrap"
  local f = io.open(flag, "r")
  if f then
    f:close()
    return false
  end
  return true
end

return M
