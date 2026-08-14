-- AI STAR CUBE · multi-pane desktop layouts
local wezterm = require("wezterm")
local act = wezterm.action
local launch = require("workbench.launch")
local desk = require("workbench.desk")

local M = {}

local function ps()
  return launch.powershell
end

local function toast(window, title, msg)
  window:toast_notification(title, msg, nil, 2800)
end

--- H-1/M-1: R1 path gate + agent availability gate — BOTH must pass BEFORE any
--- spawn. Weak/unbound path or missing CLI → toast + return, no orphan tab,
--- no "'kimi' 不是命令" dead pane (D-005: one missing agent never blocks peers).
local function gate_spawn(window, cwd_path, agent, title)
  if not desk.is_strong_path(cwd_path) then
    toast(window, title, "无可靠项目路径 — 先在 Init 面板选定任务（或按 c 创建）", 4500)
    return false
  end
  agent = agent or "grok"
  if not launch.has_agent(agent) then
    toast(
      window,
      title,
      "未找到 "
        .. agent
        .. " CLI — 请在 desk-roots 第三列改绑已安装 agent（grok/kimi/codex/deepseek）或安装它",
      5000
    )
    return false
  end
  return true
end

local function monitor_cmd(ws, root)
  local esc = (root or ""):gsub("'", "''")
  local ws_esc = (ws or "home"):gsub("'", "''")
  return launch.ps_command(
    "Write-Host ''"
      .. "; Write-Host '  ══ 任务监视 · Task Monitor ══' -ForegroundColor DarkCyan"
      .. "; Write-Host ('  工作区 WS   : {0}' -f '"
      .. ws_esc
      .. "') -ForegroundColor Yellow"
      .. "; Write-Host ('  任务根 DESK : {0}' -f '"
      .. esc
      .. "') -ForegroundColor White"
      .. "; Write-Host '  AI 对话窗格应在此目录启动；F7 Explorer 默认绑 DESK' -ForegroundColor DarkGray"
      .. "; Write-Host '  常用: git status | git diff --stat | AI agent 在左栏' -ForegroundColor DarkGray"
      .. "; Write-Host ''"
      .. "; if (Get-Command git -ErrorAction SilentlyContinue) { git -C '"
      .. esc
      .. "' status -sb 2>$null }"
  )
end

--- Fresh 3-pane desk (recommended)
--- D-004: main pane runs the task's agent (desk-roots 3rd column), grok 兜底
--- D-008: agent 平权 — F6 展开前必须先出现「全量已装 agent」选择，
--- 默认项 = D-005 路由结果排第一；Esc 取消 = 零 spawn。
--- 单一已装 agent 时跳过选择器直接启动（无选择必要）。

--- Installed peer agents, stable order grok/kimi/codex/deepseek (same set as Init 面板).
local function installed_agents()
  local out = {}
  for _, id in ipairs({ "grok", "kimi", "codex", "deepseek" }) do
    if launch.has_agent(id) then
      table.insert(out, id)
    end
  end
  return out
end

--- D-008 agent equality picker: every installed agent is an equal option;
--- the desk-roots routed default is listed first with a ▶ marker.
--- on_pick(window, pane, agent_id) fires only on a confirmed pick;
--- Esc / empty list / single agent never spawn implicitly.
local function pick_agent(window, pane, cwd_path, title, on_pick)
  local installed = installed_agents()
  if #installed == 0 then
    toast(window, title, "未检测到任何已装 agent CLI（grok/kimi/codex/deepseek）— 请先安装", 5000)
    return
  end
  -- default = D-005 routing; must be installed, else first installed peer
  local routed = desk.agent_for_path(cwd_path)
  local default_agent = installed[1]
  for _, id in ipairs(installed) do
    if id == routed then
      default_agent = id
      break
    end
  end
  if #installed == 1 then
    on_pick(window, pane, installed[1])
    return
  end
  local choices = {}
  table.insert(choices, {
    id = default_agent,
    label = "▶ " .. launch.agent_label(default_agent) .. "（默认 · desk-roots 路由）",
  })
  for _, id in ipairs(installed) do
    if id ~= default_agent then
      table.insert(choices, { id = id, label = "  " .. launch.agent_label(id) })
    end
  end
  local ok, err = pcall(function()
    window:perform_action(
      act.InputSelector({
        title = title .. " — 选择 agent（↑↓ + Enter · Esc 取消）",
        fuzzy = false,
        choices = choices,
        action = wezterm.action_callback(function(win, p, id, _)
          if not id then
            return -- Esc: cancel, zero spawn (D-008)
          end
          on_pick(win, p, id)
        end),
      }),
      pane
    )
  end)
  if not ok then
    toast(window, title, "agent 选择器失败: " .. tostring(err), 5000)
  end
end

local function spawn_workbench_fresh(window, cwd_path, agent)
  local mux_window = window:mux_window()

  local tab, main = mux_window:spawn_tab({
    args = launch.agent_args(agent, cwd_path),
    cwd = cwd_path,
  })

  local pname = desk.project_label(cwd_path)
  if main then
    desk.set_root(pname, cwd_path)
  end

  local shell = main:split({
    direction = "Right",
    size = 0.32,
    args = ps(),
    cwd = cwd_path,
  })

  if shell then
    shell:split({
      direction = "Bottom",
      size = 0.42,
      args = monitor_cmd(pname, cwd_path),
      cwd = cwd_path,
    })
  end

  main:activate()
  if tab then
    local title = "✦ " .. pname
    if agent and agent ~= "grok" then
      title = title .. " | " .. launch.agent_label(agent)
    end
    tab:set_title(title)
    if not desk.bind_tab(tab, cwd_path, main) then
      desk.set_tab_desk(window, main, cwd_path)
    end
  elseif main then
    desk.set_tab_desk(window, main, cwd_path)
  end
  toast(
    window,
    "AI 对话桌 · 新页签",
    "AI:"
      .. launch.agent_label(agent)
      .. " · PROJECT:"
      .. pname
      .. " · PATH:"
      .. desk.short_path(cwd_path, 42)
      .. " · F7 绑同 PATH"
  )
end

function M.open_workbench_fresh(window, pane)
  local ws, root = desk.ensure(window, pane)
  local cwd_path = root

  -- H-1: strong-path gate BEFORE anything spawns (R1). Agent availability is
  -- handled inside pick_agent (any installed peer may be chosen, not only the
  -- routed one), so gate_spawn's agent leg no longer applies here.
  if not desk.is_strong_path(cwd_path) then
    toast(window, "AI 对话桌", "无可靠项目路径 — 先在 Init 面板选定任务（或按 c 创建）", 4500)
    return
  end

  pick_agent(window, pane, cwd_path, "AI 对话桌", function(win, _p, agent)
    spawn_workbench_fresh(win, cwd_path, agent)
  end)
end

--- Split current tab in place
function M.open_workbench(window, pane)
  local ws, root = desk.ensure(window, pane)
  local cwd_path = root
  desk.set_tab_desk(window, pane, cwd_path)

  local shell = pane:split({
    direction = "Right",
    size = 0.32,
    args = ps(),
    cwd = cwd_path,
  })

  if shell then
    shell:split({
      direction = "Bottom",
      size = 0.42,
      args = monitor_cmd(ws, cwd_path),
      cwd = cwd_path,
    })
  end

  -- D-004: start the task's agent in the desk root.
  -- kimi has no --cwd (identity = process cwd → Set-Location is enough);
  -- codex takes its cwd from the shell; grok keeps explicit --cwd.
  -- H-1/M-1: never inject an AI session identity on a weak/unbound path,
  -- and never inject a CLI that is not installed (dead red error in-shell).
  local agent = desk.agent_for_path(cwd_path) or "grok"
  local ai_cmd = nil
  if not desk.is_strong_path(cwd_path) then
    pane:activate()
    toast(window, "In-place desk", "无可靠项目路径 — 未注入 AI 命令（R1）", 4500)
    return
  end
  local esc = cwd_path:gsub("'", "''")
  if launch.has_agent(agent) then
    if agent == "kimi" then
      ai_cmd = "kimi"
    elseif agent == "codex" then
      ai_cmd = "codex"
    elseif agent == "deepseek" then
      -- kimi pattern: no --cwd flag; process cwd (Set-Location) is identity
      ai_cmd = "deepseek"
    else
      ai_cmd = "& '" .. launch.grok_exe:gsub("'", "''") .. "' --cwd '" .. esc .. "'"
    end
  end

  pane:activate()
  if not ai_cmd then
    toast(
      window,
      "In-place desk",
      "DESK " .. desk.short_path(cwd_path, 40) .. " · 未找到 " .. agent .. " CLI，未注入 AI 命令",
      4500
    )
    return
  end
  pane:send_text("Set-Location -LiteralPath '" .. esc .. "'; " .. ai_cmd .. "\r")
  toast(
    window,
    "In-place desk",
    "DESK " .. desk.short_path(cwd_path, 40) .. " · " .. launch.agent_label(agent)
  )
end

function M.open_dual_ai(window, pane)
  local ws, root = desk.ensure(window, pane)
  local cwd_path = root
  local mux_window = window:mux_window()

  -- D-004: left = task's agent (desk-roots 3rd column), right = 对照 agent
  -- H-1/M-1: gates BEFORE spawn; 对照 agent 也必须真实存在，否则右栏是废窗格
  local agent = desk.agent_for_path(cwd_path) or "grok"
  if not gate_spawn(window, cwd_path, agent, "Dual AI") then
    return
  end
  local peer = nil
  for _, cand in ipairs({ "kimi", "codex", "deepseek", "grok" }) do
    if cand ~= agent and launch.has_agent(cand) then
      peer = cand
      break
    end
  end
  if not peer then
    toast(window, "Dual AI", "没有可用的对照 agent — 再装一个 CLI（grok/kimi/codex/deepseek）", 5000)
    return
  end

  local tab, left = mux_window:spawn_tab({
    args = launch.agent_args(agent, cwd_path),
    cwd = cwd_path,
  })

  left:split({
    direction = "Right",
    size = 0.5,
    args = launch.agent_args(peer, cwd_path),
    cwd = cwd_path,
  })

  left:activate()
  if tab then
    tab:set_title("⚔ " .. desk.basename(cwd_path))
  end
  toast(
    window,
    "Dual AI · 新页签",
    launch.agent_label(agent) .. " × " .. launch.agent_label(peer) .. " · WS:" .. ws .. " · 同 DESK"
  )
end

function M.open_review(window, pane)
  local ws, root = desk.ensure(window, pane)
  local cwd_path = root
  local mux_window = window:mux_window()

  -- D-004: main pane = task's agent (desk-roots 3rd column)
  -- H-1/M-1: gates BEFORE spawn (also fixes nil-root gsub crash below)
  local agent = desk.agent_for_path(cwd_path) or "grok"
  if not gate_spawn(window, cwd_path, agent, "Review") then
    return
  end
  local esc = cwd_path:gsub("'", "''")

  local tab, main = mux_window:spawn_tab({
    args = launch.agent_args(agent, cwd_path),
    cwd = cwd_path,
  })

  main:split({
    direction = "Right",
    size = 0.38,
    args = launch.ps_command(
      "Write-Host '  ══ Review · 任务根 ══' -ForegroundColor Yellow"
        .. "; Write-Host '  DESK: "
        .. esc
        .. "' -ForegroundColor White"
        .. "; Write-Host '  git status; git diff; git log --oneline -20' -ForegroundColor DarkGray"
        .. "; if (Get-Command git -ErrorAction SilentlyContinue) { git -C '"
        .. esc
        .. "' status -sb }"
    ),
    cwd = cwd_path,
  })

  main:activate()
  if tab then
    tab:set_title("检 " .. desk.basename(cwd_path))
  end
  toast(window, "Review · 新页签", "WS:" .. ws)
end

--- Single-agent focus tab. D-004: all agents share this path.
--- H-1/M-1: R1 + availability gates BEFORE spawn (was: grok-only check).
local function open_focus_agent(window, pane, agent, icon)
  local _, root = desk.ensure(window, pane)
  agent = agent or "grok"
  if not gate_spawn(window, root, agent, launch.agent_label(agent) .. " · 新页签") then
    return
  end
  local mux_window = window:mux_window()
  local tab, main = mux_window:spawn_tab({
    args = launch.agent_args(agent, root),
    cwd = root,
  })
  if tab then
    tab:set_title(icon .. " " .. desk.basename(root))
  end
  if main then
    main:activate()
  end
  toast(window, launch.agent_label(agent) .. " · 新页签", "DESK " .. desk.short_path(root, 40), 2500)
end

function M.open_focus_grok(window, pane)
  open_focus_agent(window, pane, "grok", "✦")
end

function M.open_focus_kimi(window, pane)
  open_focus_agent(window, pane, "kimi", "◆")
end

function M.open_focus_codex(window, pane)
  open_focus_agent(window, pane, "codex", "◎")
end

return M
