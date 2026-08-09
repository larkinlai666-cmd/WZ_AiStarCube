-- AI STAR CUBE · multi-pane desktop layouts
local wezterm = require("wezterm")
local launch = require("workbench.launch")
local desk = require("workbench.desk")

local M = {}

local function ps()
  return launch.powershell
end

local function toast(window, title, msg)
  window:toast_notification(title, msg, nil, 2800)
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
      .. "; Write-Host '  常用: git status | git diff --stat | grok doctor' -ForegroundColor DarkGray"
      .. "; Write-Host ''"
      .. "; if (Get-Command git -ErrorAction SilentlyContinue) { git -C '"
      .. esc
      .. "' status -sb 2>$null }"
  )
end

--- Fresh 3-pane desk (recommended)
function M.open_workbench_fresh(window, pane)
  local ws, root = desk.ensure(window, pane)
  local cwd_path = root
  local mux_window = window:mux_window()

  local tab, main = mux_window:spawn_tab({
    args = launch.grok_args(cwd_path),
    cwd = cwd_path,
  })

  if not desk.is_strong_path(cwd_path) then
    toast(window, "AI 对话桌", "无可靠项目路径 — 先 F9 选项目或 Init c 创建", 4500)
    return
  end
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
    tab:set_title("✦ " .. pname)
    if not desk.bind_tab(tab, cwd_path, main) then
      desk.set_tab_desk(window, main, cwd_path)
    end
  elseif main then
    desk.set_tab_desk(window, main, cwd_path)
  end
  toast(
    window,
    "AI 对话桌 · 新页签",
    "PROJECT:" .. pname .. " · PATH:" .. desk.short_path(cwd_path, 42) .. " · F7 绑同 PATH"
  )
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

  -- Prefer launching grok in desk root with --cwd alignment
  local esc = cwd_path:gsub("'", "''")
  local grok = launch.grok_exe:gsub("'", "''")
  pane:send_text(
    "Set-Location -LiteralPath '"
      .. esc
      .. "'; & '"
      .. grok
      .. "' --cwd '"
      .. esc
      .. "'\r"
  )
  pane:activate()
  toast(window, "In-place desk", "DESK " .. desk.short_path(cwd_path, 40) .. " · Grok --cwd")
end

function M.open_dual_ai(window, pane)
  local ws, root = desk.ensure(window, pane)
  local cwd_path = root
  local mux_window = window:mux_window()

  local tab, left = mux_window:spawn_tab({
    args = launch.grok_args(cwd_path),
    cwd = cwd_path,
  })

  left:split({
    direction = "Right",
    size = 0.5,
    args = launch.codex_args(),
    cwd = cwd_path,
  })

  left:activate()
  if tab then
    tab:set_title("⚔ " .. desk.basename(cwd_path))
  end
  toast(window, "Dual AI · 新页签", "WS:" .. ws .. " · 同 DESK")
end

function M.open_review(window, pane)
  local ws, root = desk.ensure(window, pane)
  local cwd_path = root
  local mux_window = window:mux_window()
  local esc = cwd_path:gsub("'", "''")

  local tab, main = mux_window:spawn_tab({
    args = launch.grok_args(cwd_path),
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

function M.open_focus_grok(window, pane)
  local _, root = desk.ensure(window, pane)
  local mux_window = window:mux_window()
  local tab, main = mux_window:spawn_tab({
    args = launch.grok_args(root),
    cwd = root,
  })
  if tab then
    tab:set_title("✦ " .. desk.basename(root))
  end
  main:activate()
  toast(window, "Grok · 新页签", "DESK " .. desk.short_path(root, 40), 2500)
end

function M.open_focus_codex(window, pane)
  local _, root = desk.ensure(window, pane)
  local mux_window = window:mux_window()
  local tab, main = mux_window:spawn_tab({
    args = launch.codex_args(),
    cwd = root,
  })
  if tab then
    tab:set_title("◎ " .. desk.basename(root))
  end
  main:activate()
  toast(window, "Codex · 新页签", "DESK " .. desk.short_path(root, 40), 2500)
end

return M
