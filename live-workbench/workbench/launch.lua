-- AI STAR CUBE · launch menu, tool paths, spawn helpers
local wezterm = require("wezterm")

local M = {}

local home = wezterm.home_dir
M.home = home
M.powershell = { "powershell.exe", "-NoLogo", "-NoProfile" }

--- True if path is readable (no subprocess — safe at config load)
local function file_exists(p)
  if not p or p == "" then
    return false
  end
  local f = io.open(p, "r")
  if f then
    f:close()
    return true
  end
  return false
end

M.bootstrap_ps1 = home .. "\\.config\\wezterm\\workbench\\bootstrap.ps1"
M.escape_wrap_ps1 = home .. "\\.config\\wezterm\\workbench\\escape-wrap.ps1"
M.agent_discovery_ps1 = home .. "\\.config\\wezterm\\workbench\\agent-discovery.ps1"
M.no_bootstrap_flag = home .. "\\.config\\wezterm\\workbench\\no-bootstrap"

-- D-016: MUST NOT call wezterm.run_child_process at require/config-load time.
-- Defer discovery until a user action. run_child_process at require()
-- time can invalidate the WezTerm config; F6 and other runtime actions are safe.
-- The helper returns arbitrary product ids, so Lua has no agent whitelist.
local agent_defs = nil
local agent_order = nil

local function parse_agent_tsv(text)
  local defs = {}
  local order = {}
  for line in tostring(text or ""):gmatch("[^\r\n]+") do
    local id, label, exe, source = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t?(.*)$")
    if id and exe and file_exists(exe) then
      id = tostring(id):lower()
      defs[id] = { id = id, label = label, exe = exe, source = source }
      table.insert(order, id)
    end
  end
  return defs, order
end

function M.refresh_agents()
  if not file_exists(M.agent_discovery_ps1) then
    agent_defs, agent_order = {}, {}
    wezterm.GLOBAL.wz_agent_route_ids = {}
    return {}
  end
  local ok, stdout = wezterm.run_child_process({
    "powershell.exe",
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    M.agent_discovery_ps1,
    "-AsTsv",
  })
  if ok then
    agent_defs, agent_order = parse_agent_tsv(stdout)
  else
    agent_defs, agent_order = {}, {}
  end
  -- Runtime-only handoff for desk.lua process recognition. This keeps process
  -- matching data-driven without triggering discovery from status/HUD ticks.
  wezterm.GLOBAL.wz_agent_route_ids = agent_order or {}
  return agent_order
end

local function ensure_agents()
  if agent_defs == nil then
    M.refresh_agents()
  end
end

function M.installed_agents(refresh)
  if refresh or agent_defs == nil then
    M.refresh_agents()
  end
  local out = {}
  for _, id in ipairs(agent_order or {}) do
    table.insert(out, id)
  end
  return out
end

--- Cold start / new tab: NEVER point at bootstrap.ps1 directly.
--- escape-wrap.ps1 runs Init and falls back to a plain shell if Init dies.
function M.bootstrap_args()
  local wrap = M.escape_wrap_ps1
  local f = io.open(wrap, "r")
  if f then
    f:close()
    return {
      "powershell.exe",
      "-NoLogo",
      "-NoProfile",
      "-NoExit",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      wrap,
    }
  end
  -- Last-ditch: wrap file missing (partial install) — bare shell, not Init.
  return M.powershell
end

--- Raw Init (F3 wizard only). Must not be used as default_prog.
function M.bootstrap_raw_args()
  return {
    "powershell.exe",
    "-NoLogo",
    "-NoProfile",
    "-NoExit",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    M.bootstrap_ps1,
  }
end

--- F3: create-project wizard only (same engine as Init key "c")
function M.wizard_args()
  return {
    "powershell.exe",
    "-NoLogo",
    "-NoProfile",
    "-NoExit",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    M.bootstrap_ps1,
    "-WizardOnly",
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
  return {
    "powershell.exe",
    "-NoLogo",
    "-NoProfile",
    "-NoExit",
    "-ExecutionPolicy",
    "Bypass",
    "-Command",
    cmd,
  }
end

local function ps_literal(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

--- One immediate cat frame, then exec. No Sleep: the frame stays on screen
--- while the CLI boots and is replaced when a TUI takes the console.
local function splash_prefix(label, project)
  label = tostring(label or "agent"):gsub("'", "''")
  project = tostring(project or ""):gsub("'", "''")
  return table.concat({
    "try { [Console]::Clear() } catch {}",
    "Write-Host ''",
    "Write-Host '   /\\_/\\' -ForegroundColor Magenta",
    "Write-Host '  ( o.o )' -ForegroundColor Magenta",
    "Write-Host '   > ^ <' -ForegroundColor Magenta",
    "Write-Host '  handing off to agent process...' -ForegroundColor DarkGray",
    "Write-Host ('  " .. project .. " · " .. label .. "') -ForegroundColor Gray",
  }, "; ")
end

function M.handoff_args(exe, args, opts)
  opts = opts or {}
  local run = "& " .. ps_literal(exe)
  for _, arg in ipairs(args or {}) do
    run = run .. " " .. ps_literal(arg)
  end
  local body = splash_prefix(opts.label, opts.project)
  if opts.clear_before then
    body = body .. "; try { [Console]::Clear() } catch {}"
  end
  body = body .. "; " .. run
  local argv = {
    "powershell.exe",
    "-NoLogo",
    "-NoProfile",
  }
  if opts.keep_open then
    table.insert(argv, "-NoExit")
  end
  table.insert(argv, "-ExecutionPolicy")
  table.insert(argv, "Bypass")
  table.insert(argv, "-Command")
  table.insert(argv, body)
  return argv
end

--- Build a launch argv from the exact path returned by open discovery.
--- Every Agent gets a zero-sleep cover frame. Native .exe still uses a
--- PowerShell host so the 2-5s TUI boot is not a black pane. Shims keep
--- -NoExit because CreateProcess cannot use .cmd/.bat/.ps1 as argv0.
function M.command_args(agent, args)
  local exe = M.resolve_agent_exe(agent)
  if not exe or not file_exists(exe) then
    return nil
  end
  args = args or {}
  local lower = tostring(exe):lower()
  local native = lower:match("%.exe$") or lower:match("%.com$")
  return M.handoff_args(exe, args, {
    label = M.agent_label(agent),
    keep_open = not native,
    clear_before = (tostring(agent or ""):lower() == "deepseek"),
  })
end

--- Args that start the optional Grok adapter when present
--- opts.continue  → -c (resume most recent session for this cwd)
--- opts.resume    → -r <id-or-title>
function M.grok_args(cwd, opts)
  opts = opts or {}
  local args = {}
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
  return M.command_args("grok", args)
end

function M.grok_continue_args(cwd)
  return M.grok_args(cwd, { continue_session = true })
end

function M.codex_args(opts)
  opts = opts or {}
  local args = {}
  if opts["continue"] or opts.continue_session then
    args = { "resume", "--last" }
  end
  return M.command_args("codex", args)
end

--- F-014: DeepSeek CLI — npm .cmd shim, same PowerShell-host pattern; no
--- --cwd flag (process cwd = project identity), resume = --continue.
function M.deepseek_args(opts)
  opts = opts or {}
  local args = {}
  if opts["continue"] or opts.continue_session then
    args = { "--continue" }
  end
  return M.command_args("deepseek", args)
end

--- D-004: kimi has no --cwd; task identity = process cwd (spawn cwd).
--- Same PowerShell-host pattern as codex (shim-safe, keeps tab open on exit).
function M.kimi_args(opts)
  opts = opts or {}
  local args = {}
  if opts["continue"] or opts.continue_session then
    -- Same-model handover: resume most recent session in this cwd
    args = { "--continue" }
  end
  return M.command_args("kimi", args)
end

--- D-016: all discovered agents are peers. Product-specific branches below are
--- optional resume adapters, never a discovery whitelist or unknown fallback.
--- opts.continue_session → resume the agent's latest session for this cwd.
function M.agent_args(agent, cwd, opts)
  opts = opts or {}
  agent = tostring(agent or ""):lower()
  if not M.resolve_agent_exe(agent) then
    return nil
  end
  local cont = opts["continue"] or opts.continue_session
  if agent == "kimi" then
    return M.kimi_args({ continue_session = cont })
  end
  if agent == "codex" then
    return M.codex_args({ continue_session = cont })
  end
  if agent == "deepseek" then
    return M.deepseek_args({ continue_session = cont })
  end
  if agent == "grok" then
    if cont then
      return M.grok_continue_args(cwd)
    end
    return M.grok_args(cwd)
  end
  return M.command_args(agent)
end

--- Display name for toasts / tab titles
function M.agent_label(agent)
  ensure_agents()
  agent = tostring(agent or ""):lower()
  local def = agent_defs and agent_defs[agent]
  return (def and def.label) or agent
end

--- Compatibility helper for the optional Grok resume adapter.
function M.has_grok()
  return M.resolve_agent_exe("grok") ~= nil
end

function M.resolve_agent_exe(agent)
  ensure_agents()
  agent = tostring(agent or ""):lower()
  local def = agent_defs and agent_defs[agent]
  return def and def.exe or nil
end

function M.has_agent(agent)
  return M.resolve_agent_exe(agent) ~= nil
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
  -- R1/M2-6: never advertise bare agent sessions @ home — an agent's identity
  -- must be a bound project (D-003). Real work starts from the Init panel;
  -- the only escapes below are plain shells; no product gets a private menu.
  config.launch_menu = {
    {
      label = "★ WZ 逃生壳（纯 PowerShell，不跑 Init）",
      args = M.powershell,
      cwd = home,
    },
    {
      label = "★ WZ 任务初始化面板（选/建项目后再开 AI）",
      args = M.bootstrap_args(),
      cwd = home,
    },
    {
      label = "■ PowerShell（纯 shell，无初始化面板）",
      args = M.powershell,
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
