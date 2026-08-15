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

--- Open the table init panel in a new tab (mouse + / cold start preferred)
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

--- F3: jump straight into NEW PROJECT wizard (not Init table)
function M.show_new_project(window, pane)
  local mux_window = window:mux_window()
  local tab, main = mux_window:spawn_tab({
    args = launch.wizard_args(),
    cwd = home,
  })
  if main then
    main:activate()
  end
  if tab then
    pcall(function()
      tab:set_title("新建项目")
    end)
  end
  toast(
    window,
    "新建本地项目",
    "名 → 选父目录 → 确认冻结 → 开 AI 对话  |  q 取消",
    5000
  )
end

--- Continue latest session for current tab project (fast path)
--- Dispatch by the task route; an unbound legacy row uses open discovery first.
function M.continue_current(window, pane)
  local name, root = desk.resolve_tab_task(window, pane)
  if not desk.is_strong_path(root) then
    toast(window, "继续对话", "当前页签无可靠项目路径 → 打开初始化面板", 4000)
    M.show_hub(window, pane)
    return
  end
  local agent = desk.agent_for_path(root)
  if not agent or not launch.has_agent(agent) then
    local available = launch.installed_agents(true)
    agent = available[1]
  end
  -- M-1 (D-005): check the RESOLVED agent, not just grok — a bound-but-
  -- uninstalled CLI must toast here instead of dying in a new tab.
  if not launch.has_agent(agent) then
    toast(
      window,
      "继续对话",
      "未找到可用 Agent CLI — 请安装自描述 Agent 或修正 desk-roots 第三列",
      5000
    )
    return
  end
  local args = launch.agent_args(agent, root, { continue_session = true })
  if not args then
    toast(window, "继续对话", "Agent inventory changed — reopen Init or retry", 4500)
    return
  end
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
  local resume_cmd = launch.agent_label(agent) .. "（按项目 cwd 新开；无专属续聊适配器）"
  if agent == "grok" then
    resume_cmd = "grok --continue"
  end
  if agent == "kimi" then
    resume_cmd = "kimi --continue"
  elseif agent == "codex" then
    resume_cmd = "codex resume --last"
  elseif agent == "deepseek" then
    resume_cmd = "deepseek --continue"
  end
  toast(window, "继续对话", resume_cmd .. " · " .. pname .. " · " .. desk.short_path(root, 36), 3500)
end

--- Used by gui-startup: should first window be the bootstrap panel?
function M.should_bootstrap_on_startup(cmd)
  -- If the caller passed an explicit non-shell program, respect it. This is
  -- deliberately product-neutral: a newly installed Agent must not be hidden
  -- behind Init merely because its name never appeared in this source tree.
  if cmd and cmd.args and #cmd.args > 0 then
    local a0 = tostring(cmd.args[1] or ""):lower()
    if a0:find("bootstrap.ps1", 1, true) then
      return false -- already bootstrapping
    end
    local leaf = a0:gsub("/", "\\"):match("([^\\]+)$") or a0
    local plain_shell = leaf == "powershell"
      or leaf == "powershell.exe"
      or leaf == "pwsh"
      or leaf == "pwsh.exe"
      or leaf == "cmd"
      or leaf == "cmd.exe"
    if not plain_shell or #cmd.args > 1 then
      return false
    end
    -- Bare shell without our panel → still show bootstrap as home.
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
