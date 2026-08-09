-- AI STAR CUBE · launch menu, tool paths, spawn helpers
local wezterm = require("wezterm")

local M = {}

local home = wezterm.home_dir
M.home = home
M.powershell = { "powershell.exe", "-NoLogo" }
M.grok_exe = home .. "\\.grok\\bin\\grok.exe"
M.bootstrap_ps1 = home .. "\\.config\\wezterm\\workbench\\bootstrap.ps1"
M.no_bootstrap_flag = home .. "\\.config\\wezterm\\workbench\\no-bootstrap"

--- Task init panel (startup + new tab default)
function M.bootstrap_args()
  return {
    "powershell.exe",
    "-NoLogo",
    "-NoExit",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    M.bootstrap_ps1,
  }
end

function M.bootstrap_enabled()
  local f = io.open(M.no_bootstrap_flag, "r")
  if f then
    f:close()
    return false
  end
  return true
end

--- default_prog for new tabs / + button (panel or plain shell)
function M.default_prog()
  if M.bootstrap_enabled() then
    return M.bootstrap_args()
  end
  return M.powershell
end

--- Args that start an interactive PowerShell running a command
function M.ps_command(cmd)
  return { "powershell.exe", "-NoLogo", "-NoExit", "-Command", cmd }
end

--- Args that start Grok directly when possible
--- opts.continue  → -c (resume most recent session for this cwd)
--- opts.resume    → -r <id-or-title>
--- opts.dashboard → open Agent Dashboard
function M.grok_args(cwd, opts)
  opts = opts or {}
  if opts.dashboard then
    local args = { M.grok_exe, "dashboard" }
    if cwd and tostring(cwd) ~= "" then
      -- dashboard is global, but start process with project cwd for context
      return args, cwd
    end
    return args, nil
  end
  local args = { M.grok_exe }
  if cwd and tostring(cwd) ~= "" then
    table.insert(args, "--cwd")
    table.insert(args, tostring(cwd))
  end
  if opts.resume and tostring(opts.resume) ~= "" then
    table.insert(args, "--resume")
    table.insert(args, tostring(opts.resume))
  elseif opts["continue"] or opts.continue_session then
    table.insert(args, "--continue")
  end
  return args
end

function M.grok_continue_args(cwd)
  return M.grok_args(cwd, { continue_session = true })
end

function M.codex_args()
  -- winget shim is a .cmd; go through PowerShell so PATH resolves cleanly
  return M.ps_command("codex")
end

--- Resolve first existing WezTerm GUI window id (for cli spawn from outside)
function M.first_gui_window_id()
  local ok, stdout = wezterm.run_child_process({
    "wezterm",
    "cli",
    "list",
    "--format",
    "json",
  })
  if not ok or not stdout or stdout == "" then
    return nil
  end
  -- Prefer parsing win ids from text list if json format unsupported
  local id = tostring(stdout):match('"window_id"%s*:%s*(%d+)')
    or tostring(stdout):match("WINID[^%d]*(%d+)")
  if id then
    return tonumber(id)
  end
  -- Plain table from `wezterm cli list` (no --format): first column is WINID
  for line in tostring(stdout):gmatch("[^\r\n]+") do
    local w = line:match("^%s*(%d+)%s+")
    if w then
      return tonumber(w)
    end
  end
  return nil
end

function M.apply(config)
  -- R1: never advertise "Grok new chat @ home" as a project workspace.
  -- Real work starts from Init panel (bind project) or F9 → F6.
  config.launch_menu = {
    {
      label = "★ WZ 任务初始化面板（选/建项目后再开 Grok）",
      args = M.bootstrap_args(),
      cwd = home,
    },
    {
      label = "▦ Grok Agent Dashboard（会话面板，非项目）",
      args = { M.grok_exe, "dashboard" },
      cwd = home,
    },
    {
      label = "■ PowerShell（纯 shell，无初始化面板）",
      args = M.powershell,
      cwd = home,
    },
    {
      label = "◎ Codex",
      args = M.codex_args(),
      cwd = home,
    },
    {
      label = "⌘ CMD",
      args = { "cmd.exe", "/k" },
      cwd = home,
    },
  }

  -- Domain: keep local mux only (no surprise remote attaches)
  config.unix_domains = {}
  config.ssh_domains = {}
end

return M
