-- AI STAR CUBE · launch menu, tool paths, spawn helpers
local wezterm = require("wezterm")

local M = {}

local home = wezterm.home_dir
M.home = home
M.powershell = { "powershell.exe", "-NoLogo" }

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

--- Resolve an agent CLI portably (D-004: all peers).
--- MUST NOT call wezterm.run_child_process here: this runs at require() during
--- config evaluation; child process yield → "attempt to yield across a C-call
--- boundary" and WezTerm falls back to a blank default config (lost workbench).
--- M-4: PATH scan skips UNC (\\host\share) and empty entries — io.open on a
--- network root can block hundreds of ms PER entry at config load.
local AGENT_EXE_NAMES = {
  grok = { "grok.exe", "grok.cmd" },
  kimi = { "kimi.exe", "kimi.cmd" },
  codex = { "codex.exe", "codex.cmd" },
  deepseek = { "deepseek.cmd", "deepseek.exe", "deepseek" },
}

local function agent_fixed_candidates(agent)
  local c = {}
  local la = os.getenv("LOCALAPPDATA")
  if agent == "grok" then
    table.insert(c, home .. "\\.grok\\bin\\grok.exe")
    if la and la ~= "" then
      table.insert(c, la .. "\\Programs\\grok\\grok.exe")
      table.insert(c, la .. "\\grok\\bin\\grok.exe")
    end
  elseif agent == "kimi" then
    table.insert(c, home .. "\\.kimi-code\\bin\\kimi.exe")
    table.insert(c, home .. "\\.kimi\\bin\\kimi.exe")
  elseif agent == "codex" then
    if la and la ~= "" then
      table.insert(c, la .. "\\Programs\\codex\\codex.exe")
    end
    local ap = os.getenv("APPDATA")
    if ap and ap ~= "" then
      table.insert(c, ap .. "\\npm\\codex.cmd")
    end
  elseif agent == "deepseek" then
    -- npm global install (@kavienw/deepseek-cli) → %APPDATA%\npm\deepseek.cmd
    local apd = os.getenv("APPDATA")
    if apd and apd ~= "" then
      table.insert(c, apd .. "\\npm\\deepseek.cmd")
    end
  end
  return c
end

--- Fixed candidates first, then PATH dirs (pure env + io; no where.exe).
--- Returns full path or nil when the agent CLI is not installed.
local function find_agent_exe(agent)
  local names = AGENT_EXE_NAMES[agent]
  if not names then
    return nil
  end
  for _, p in ipairs(agent_fixed_candidates(agent)) do
    if file_exists(p) then
      return p
    end
  end
  local path_env = os.getenv("PATH") or os.getenv("Path") or ""
  for dir in path_env:gmatch("[^;]+") do
    dir = tostring(dir):gsub("^%s+", ""):gsub("%s+$", ""):gsub("[/\\]+$", "")
    if dir ~= "" and not dir:match("^[/\\][/\\]") then
      for _, name in ipairs(names) do
        local p = dir .. "\\" .. name
        if file_exists(p) then
          return p
        end
      end
    end
  end
  return nil
end

local function resolve_grok_exe()
  -- fallback path (error messages still make sense)
  return find_agent_exe("grok") or (home .. "\\.grok\\bin\\grok.exe")
end

M.grok_exe = resolve_grok_exe()
M.bootstrap_ps1 = home .. "\\.config\\wezterm\\workbench\\bootstrap.ps1"
M.no_bootstrap_flag = home .. "\\.config\\wezterm\\workbench\\no-bootstrap"

--- Task init panel (startup + new tab default / + button)
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

--- F3: create-project wizard only (same engine as Init key "c")
function M.wizard_args()
  return {
    "powershell.exe",
    "-NoLogo",
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

--- F-014: DeepSeek CLI — npm .cmd shim, same PowerShell-host pattern; no
--- --cwd flag (process cwd = project identity), resume = --continue.
function M.deepseek_args()
  return M.ps_command("deepseek")
end

--- D-004: kimi has no --cwd; task identity = process cwd (spawn cwd).
--- Same PowerShell-host pattern as codex (shim-safe, keeps tab open on exit).
function M.kimi_args(opts)
  opts = opts or {}
  if opts["continue"] or opts.continue_session then
    -- Same-model handover: resume most recent session in this cwd
    return M.ps_command("kimi --continue")
  end
  return M.ps_command("kimi")
end

--- D-004: agents are peers. Route spawn args by the task's agent.
--- agent: "grok" (缺省/unknown fallback) / "kimi" / "codex".
--- opts.continue_session → resume the agent's latest session for this cwd.
function M.agent_args(agent, cwd, opts)
  opts = opts or {}
  local cont = opts["continue"] or opts.continue_session
  if agent == "kimi" then
    return M.kimi_args({ continue_session = cont })
  end
  if agent == "codex" then
    if cont then
      -- codex sessions live in ~/.codex/sessions; --last resumes the newest
      return M.ps_command("codex resume --last")
    end
    return M.codex_args()
  end
  if agent == "deepseek" then
    if cont then
      -- per-cwd session: ~/.deepseek-cli/sessions/<sha256(cwd)[0:16]>.json
      return M.ps_command("deepseek --continue")
    end
    return M.deepseek_args()
  end
  if cont then
    return M.grok_continue_args(cwd)
  end
  return M.grok_args(cwd)
end

--- Display name for toasts / tab titles
function M.agent_label(agent)
  if agent == "kimi" then
    return "Kimi"
  end
  if agent == "codex" then
    return "Codex"
  end
  if agent == "deepseek" then
    return "DeepSeek"
  end
  return "Grok"
end

--- True when grok.exe was actually found (pure io check; safe at runtime).
--- Callers must degrade gracefully (toast) instead of spawning a dead path.
function M.has_grok()
  return file_exists(M.grok_exe)
end

--- M-1 (D-005 平权): runtime availability for any agent CLI, memoized per
--- config generation. kimi/codex spawn via PowerShell shims — checking here
--- prevents "'kimi' 不是命令" dead tabs when a bound agent was uninstalled.
local agent_exe_memo = {}

function M.resolve_agent_exe(agent)
  agent = tostring(agent or "grok"):lower()
  if agent == "grok" then
    if M.has_grok() then
      return M.grok_exe
    end
    return nil
  end
  if agent_exe_memo[agent] == nil then
    agent_exe_memo[agent] = find_agent_exe(agent) or false
  end
  return agent_exe_memo[agent] or nil
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
  -- R1: never advertise "Grok new chat @ home" as a project workspace.
  -- Real work starts from Init panel (bind project) or F9 → F6.
  config.launch_menu = {
    {
      label = "★ WZ 任务初始化面板（选/建项目后再开 AI）",
      args = M.bootstrap_args(),
      cwd = home,
    },
    {
      label = "▦ Grok Agent Dashboard（grok 专属会话面板，非项目）",
      args = { M.grok_exe, "dashboard" },
      cwd = home,
    },
    {
      label = "■ PowerShell（纯 shell，无初始化面板）",
      args = M.powershell,
      cwd = home,
    },
    {
      label = "◆ Kimi",
      args = M.kimi_args(),
      cwd = home,
    },
    {
      label = "◎ Codex",
      args = M.codex_args(),
      cwd = home,
    },
    {
      label = "◇ DeepSeek",
      args = M.deepseek_args(),
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
