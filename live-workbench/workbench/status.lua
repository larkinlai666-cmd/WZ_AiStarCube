-- WZ-AiWorkBench · top chrome
--
-- Three info classes only:
--   1) Brand — fixed left anchor " ★ AI STAR CUBE " (never moves)
--   2) Path  — full path, left edge fixed after brand; width grows rightward
--   3) Tabs  — dynamic "project · tool"
--
-- Path bar policy (2026-08-08, user):
--   - Left origin of the path slab stays absolutely fixed (same as today)
--   - Do NOT hardcode total bar length (PATH_W force-width caused repeated bugs)
--   - Show full path (全量展示); stretch dynamically to the right with content
--
local wezterm = require("wezterm")
local desk = require("workbench.desk")

local M = {}

local function route_label(id)
  local text = tostring(id or ""):gsub("[-_]", " ")
  return (text:gsub("(%a)([%w']*)", function(first, rest)
    return first:upper() .. rest
  end))
end

-- Bump on every status logic change so stacked old handlers no-op
local STATUS_GEN = 29

-- Catppuccin Mocha accents (same family as config.color_scheme):
--   brand  = Yellow  #f9e2af  (identity, fixed)
--   path   = Peach   #fab387  (task path focus — selected chrome, NOT tab blue)
--   tab_on = Blue    #89b4fa  (active tab only)
--   surface = Mantle  #1e1e2e  (unselected / empty)
-- Selected chrome rule: light tinted bg + black text; each role has its own hue.
local C = {
  brand_bg = "#f9e2af", -- Yellow
  brand_fg = "#11111b",
  -- Path slot (bound): Peach selected chip — distinct from tab Blue & brand Yellow
  path_bg = "#fab387",
  path_fg = "#11111b",
  -- Path slot (unbound): unselected surface
  path_empty_bg = "#1e1e2e",
  path_empty_fg = "#7f849c",
  gap_bg = "#11111b",
  tab_on_bg = "#89b4fa", -- Blue
  tab_on_fg = "#11111b",
  tab_off_bg = "#1e1e2e",
  tab_off_fg = "#a6adc8",
  tab_hover_bg = "#45475a",
  tab_hover_fg = "#cdd6f4",
  tab_unseen_fg = "#cdd6f4",
  tab_unseen_bg = "#1e1e2e",
}

-- Brand is the only fixed-width left block (stable origin for path slab)
local BRAND_TEXT = "  ★  AI STAR CUBE   "
-- Small fixed gap between brand and path (keeps path left edge absolute)
local BRAND_PATH_GAP = "   "
-- Breathing room inside the path colored slab (not a total-width lock)
local PATH_PAD_L = " "
local PATH_PAD_R = " "

local function chip(cells, bg, fg, text, bold)
  table.insert(cells, { Background = { Color = bg } })
  table.insert(cells, { Foreground = { Color = fg } })
  if bold then
    table.insert(cells, { Attribute = { Intensity = "Bold" } })
  end
  table.insert(cells, { Text = text })
  table.insert(cells, "ResetAttributes")
end

local function cell_width(s)
  s = tostring(s or "")
  local ok, w = pcall(function()
    return wezterm.column_width(s)
  end)
  if ok and type(w) == "number" then
    return w
  end
  return #s
end

--- Full path for display. Prefer absolute drive form (全量); no max width.
local function path_display(root)
  root = desk.normalize(root)
  if not root or root == "" then
    return nil
  end
  -- Always backslash form; keep full absolute path (no ~ shorten, no ellipsis)
  return root:gsub("/", "\\")
end

local function hud_enabled()
  local g = wezterm.GLOBAL.star_cube_hud
  if g == nil then
    return true
  end
  return g and true or false
end

function M.toggle_hud(window, pane)
  local on = not hud_enabled()
  wezterm.GLOBAL.star_cube_hud = on
  if window then
    pcall(function()
      window:toast_notification(
        "顶栏",
        on and "品牌固定 + 路径全量向右延展 + 页签" or "已关",
        nil,
        2500
      )
    end)
    pcall(function()
      window:set_left_status("")
      window:set_right_status("")
    end)
  end
end

--- Role chip for tab bar. NEVER return the word "Tab" (looks like a WezTerm bug).
--- When AI is launched via PowerShell host, foreground is often "powershell.exe"
--- or "node.exe" — also inspect tab/pane title set by the launcher.
local function tab_tool(proc, title)
  proc = (proc or ""):lower()
  title = (title or ""):lower()

  -- Generic launcher title contract: "project | <dynamic agent label>".
  local title_agent = title:match("|%s*([^|]+)%s*$")
  if title_agent and title_agent ~= "shell" and title_agent ~= "app" then
    return route_label(title_agent)
  end

  if proc:find("node", 1, true) then
    -- node host for several CLIs; title should have won already
    return "AI"
  end
  if proc:find("sidebar", 1, true) or proc:find("explorer", 1, true) then
    return "Files"
  end
  if proc:find("bootstrap", 1, true) or proc:find("wz%-init", 1, true) or title:find("new project", 1, true) then
    return "Init"
  end
  if proc:find("cheatsheet", 1, true) or title:find("help", 1, true) then
    return "Help"
  end
  if proc:find("powershell", 1, true) or proc:find("pwsh", 1, true) or proc:find("cmd", 1, true) then
    return "Shell"
  end
  return "App"
end

--- Strip path pollution so tab bar stays pure navigation (never "D:\foo\bar")
local function nav_clean(label)
  if not label or label == "" then
    return nil
  end
  label = tostring(label):gsub("^%s+", ""):gsub("%s+$", "")
  -- Absolute paths / UNC → basename only
  if label:match("^[A-Za-z]:[\\/]") or label:match("^\\\\") or label:match("^/") then
    return desk.basename(label)
  end
  -- "file:///..." leftovers
  if label:match("^file:") then
    return desk.basename(label:gsub("^file:[/\\]*", ""))
  end
  -- Drop role suffixes already embedded (Project · Shell)
  local before = label:match("^(.-)%s*[·•|]%s*")
  if before and #before >= 1 then
    label = before
  end
  -- Truncate long labels
  if #label > 16 then
    label = label:sub(1, 15) .. "..."
  end
  if label == "" or label == "." or label == ".." then
    return nil
  end
  return label
end

--- WezTerm built-in signal: pane.has_unseen_output (PaneInformation / Mux Pane).
--- This is exactly what the DEFAULT tab bar uses when format-tab-title is unset.
--- We only re-implement the *label text*; activity styling stays default-compatible:
---   Intensity Bold + brighter fg, same string length, no spinner, no extra glyphs.
local function pane_has_unseen(p)
  if not p then
    return false
  end
  local hit = false
  pcall(function()
    if type(p) == "table" then
      if p.has_unseen_output == true then
        hit = true
        return
      end
      -- Some event payloads nest the real pane
      if p.pane ~= nil then
        local ok, v = pcall(function()
          return p.pane:has_unseen_output()
        end)
        if ok and v == true then
          hit = true
        end
      end
    else
      local ok, v = pcall(function()
        return p:has_unseen_output()
      end)
      if ok and v == true then
        hit = true
      end
    end
  end)
  return hit
end

--- Mirror WezTerm default: any pane in the tab with unseen output.
--- Prefer TabInformation.panes when present (official field in format-tab-title).
local function tab_has_unseen_output(tab, pane, panes)
  -- Official: tab.panes on TabInformation (wezterm docs)
  local list = nil
  pcall(function()
    if tab and type(tab.panes) == "table" then
      list = tab.panes
    end
  end)
  if not list and type(panes) == "table" then
    list = panes
  end
  if type(list) == "table" then
    for _, p in ipairs(list) do
      if pane_has_unseen(p) then
        return true
      end
    end
  end
  return pane_has_unseen(pane)
end

--- D-012 pin: a tab containing an Init pane ALWAYS renders "Init".
--- Detection = foreground process argv contains "bootstrap.ps1"/"wz-init"
--- (the same mechanism desk.lua gating already relies on; works on every
--- birth path incl. Ctrl+T default_prog where no tab:set_title ever runs).
--- PERF (2026-08-14 二轮): get_foreground_process_info on every repaint wave
--- made the whole GUI stutter. Steady state must be pure string compares:
--- (1) pre-filter on the FREE snapshot field foreground_process_name — only
---     shell hosts (powershell/pwsh/cmd) can be the Init panel, agent panes
---     (grok/kimi/node/codex…) return false with zero mux round-trips;
--- (2) argv scan result cached per pane_id, TTL 30s, invalidated when the
---     foreground process name changes; pane_id is only resolved for the
---     shell-host minority.
local init_pane_cache = {} --- pane_id -> { ts = os.time(), v = bool, proc = string }
local INIT_CACHE_TTL = 30

local function pane_is_init(p)
  if not p then
    return false
  end
  local proc = ""
  pcall(function()
    proc = tostring(p.foreground_process_name or ""):lower()
  end)
  local shellish = proc == ""
    or proc:find("powershell", 1, true)
    or proc:find("pwsh", 1, true)
    or proc:find("cmd.exe", 1, true)
  if not shellish then
    return false
  end
  local pid = nil
  pcall(function()
    pid = p.pane_id
  end)
  if not pid then
    return false
  end
  local now = os.time()
  local ent = init_pane_cache[pid]
  if ent and ent.proc == proc and (now - ent.ts) < INIT_CACHE_TTL then
    return ent.v
  end
  local v = false
  pcall(function()
    local mp = wezterm.mux.get_pane(pid)
    local info = mp and mp:get_foreground_process_info()
    if info and info.argv then
      for _, a in ipairs(info.argv) do
        local s = tostring(a):lower()
        if s:find("bootstrap.ps1", 1, true) or s:find("wz-init", 1, true) then
          v = true
          break
        end
      end
    end
  end)
  init_pane_cache[pid] = { ts = now, v = v, proc = proc }
  return v
end

local function tab_has_init_pane(tab)
  if not tab then
    return false
  end
  local list = nil
  pcall(function()
    if type(tab.panes) == "table" then
      list = tab.panes
    end
  end)
  if (not list or #list == 0) and tab.active_pane then
    list = { tab.active_pane }
  end
  if type(list) ~= "table" then
    return false
  end
  for _, p in ipairs(list) do
    if pane_is_init(p) then
      return true
    end
  end
  return false
end

--- Pure navigation label: "Project | Role" — never full paths, never literal "Tab".
local function tab_project(tab, pane, proc)
  if tab_has_init_pane(tab) then
    return nil, "Init"
  end
  local t = tab.tab_title
  local tool = tab_tool(proc, t)
  -- Utility panes: role-only navigation (no project file bleed)
  if tool == "Init" or tool == "Help" or tool == "Files" then
    return nil, tool
  end

  local id = nil
  pcall(function()
    id = tab.tab_id
  end)
  local root = desk.get_tab_desk_by_id(id)
  if desk.is_strong_path(root) then
    return nav_clean(desk.project_label(root)), tool
  end

  if t and (tostring(t):find("初始化") or tostring(t):find("选任务") or tostring(t):find("Init") or tostring(t):find("New project")) then
    return nil, "Init"
  end

  -- Title form set by launcher: "shuaibi | Codex" or "shuaibi · Codex"
  local title_proj = tostring(t or ""):match("^(.-)%s*[|·•]%s*")
  if title_proj and title_proj ~= "" then
    title_proj = nav_clean(title_proj)
    if title_proj and not desk.is_reserved_name(title_proj) then
      local by = desk.get_root(title_proj)
      if desk.is_strong_path(by) then
        return nav_clean(desk.project_label(by)), tool
      end
      return title_proj, tool
    end
  end

  local from_title = desk.title_to_project_name(t)
  from_title = nav_clean(from_title)
  if from_title and not desk.is_reserved_name(from_title) then
    local by = desk.get_root(from_title)
    if desk.is_strong_path(by) then
      return nav_clean(desk.project_label(by)), tool
    end
    if not tostring(t or ""):match("^[A-Za-z]:[\\/]") then
      return from_title, tool
    end
  end

  -- Last resort: pane cwd → project label (bind for HUD, not raw path in tab)
  if pane then
    local cwd = nil
    pcall(function()
      if type(pane) == "table" and pane.current_working_dir then
        local u = pane.current_working_dir
        if type(u) == "table" and u.file_path then
          cwd = desk.normalize(u.file_path)
        elseif type(u) == "string" then
          cwd = desk.normalize(u)
        end
      end
    end)
    if desk.is_strong_path(cwd) then
      if id then
        desk.set_tab_desk_by_id(id, cwd)
      end
      return nav_clean(desk.project_label(cwd) or desk.basename(cwd)), tool
    end
  end

  return nil, tool
end

--- Build left status: brand (fixed origin) + path (full text, grows right).
--- Path chip uses SELECTED chrome (light bg + black text) when a project is bound,
--- matching active tab; unbound uses UNSELECTED chrome (dark bg + muted text).
local function build_left_status(root, bound, tab_id)
  local left = {}
  -- 1) Brand: fixed selected-style chip (gold + black)
  chip(left, C.brand_bg, C.brand_fg, BRAND_TEXT, true)
  -- 2) Fixed gap so path slab always starts at the same X
  chip(left, C.gap_bg, C.gap_bg, BRAND_PATH_GAP)

  local body
  local bg = C.path_bg
  local fg = C.path_fg
  local bold = true
  if not hud_enabled() then
    body = "---"
    bg = C.path_empty_bg
    fg = C.path_empty_fg
    bold = false
  elseif not bound or not desk.is_strong_path(root) then
    body = "(no project - F3)"
    bg = C.path_empty_bg
    fg = C.path_empty_fg
    bold = false
  else
    -- Full path; selected chrome (peach), not tab-blue
    body = path_display(root) or root
    bg = C.path_bg
    fg = C.path_fg
    bold = true
  end

  -- 3) Path slab: left edge fixed; right edge follows content length
  chip(left, bg, fg, PATH_PAD_L .. body .. PATH_PAD_R, bold)

  wezterm.GLOBAL.star_cube_hud_last = {
    root = root,
    bound = bound,
    tab_id = tab_id,
    body = body,
    body_cells = cell_width(body),
    gen = STATUS_GEN,
    mode = "path-selected-chrome",
  }

  return wezterm.format(left)
end

local function paint_left(window, pane)
  pcall(function()
    local ap = window:active_pane()
    if ap then
      pane = ap
    end
  end)

  local _name, root, _src, bound, tab_id = desk.resolve_active_for_hud(window, pane)
  local formatted = build_left_status(root, bound, tab_id)

  -- Force repaint only when active root/tab changed (avoid 150ms flicker)
  local sig = tostring(tab_id or "") .. "|" .. tostring(root or "") .. "|" .. tostring(bound)
  local prev = wezterm.GLOBAL.star_cube_left_sig
  if prev ~= sig then
    pcall(function()
      window:set_left_status("")
    end)
    wezterm.GLOBAL.star_cube_left_sig = sig
  end
  window:set_left_status(formatted)
end

function M.apply(config)
  wezterm.GLOBAL.star_cube_status_gen = STATUS_GEN
  -- Path bar refresh only. Unseen-output styling is applied when WezTerm
  -- repaints the tab bar (same cadence as stock UI — no forced thrash).
  config.status_update_interval = 500

  wezterm.on("update-status", function(window, pane)
    if wezterm.GLOBAL.star_cube_status_gen ~= STATUS_GEN then
      return
    end
    window:set_right_status("")
    paint_left(window, pane)
  end)

  -- Custom labels only. Activity = WezTerm's has_unseen_output + default Bold cue.
  wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
    -- Active tab: update path HUD binding (never write path into tab title)
    if tab.is_active and wezterm.GLOBAL.star_cube_status_gen == STATUS_GEN then
      local id = tab.tab_id
      local root = desk.get_tab_desk_by_id(id)
      if not desk.is_strong_path(root) then
        local pname = desk.title_to_project_name(tab.tab_title)
        pname = nav_clean(pname)
        if pname then
          root = desk.get_root(pname)
        end
      end
      if not desk.is_strong_path(root) then
        local pane = tab.active_pane
        if pane then
          local cwd = nil
          pcall(function()
            if pane.current_working_dir then
              local u = pane.current_working_dir
              if type(u) == "table" and u.file_path then
                cwd = desk.normalize(u.file_path)
              elseif type(u) == "string" then
                cwd = desk.normalize(u)
              end
            end
          end)
          -- Bind desk for HUD only — do not surface cwd path as tab title
          if desk.is_strong_path(cwd) then
            root = cwd
          end
        end
      end
      if desk.is_strong_path(root) and id then
        desk.set_tab_desk_by_id(id, root)
      end
      local prev_id = wezterm.GLOBAL.star_cube_active_tab_id
      local prev_path = wezterm.GLOBAL.star_cube_active_tab_path
      wezterm.GLOBAL.star_cube_active_tab_path = root
      wezterm.GLOBAL.star_cube_active_tab_id = id

      local changed = (prev_id ~= id) or (prev_path ~= root)
      if changed then
        pcall(function()
          if wezterm.gui and wezterm.gui.gui_windows then
            for _, gui in ipairs(wezterm.gui.gui_windows()) do
              paint_left(gui, gui:active_pane())
            end
          end
        end)
      end
    end

    local pane = tab.active_pane
    local proc = ""
    if pane then
      proc = pane.foreground_process_name or ""
    end
    local project, tool = tab_project(tab, pane, proc)
    if not tool or tool == "" then
      tool = tab_tool(proc, tab.tab_title)
    end
    -- Guard: never surface engine fallback junk in the tab bar
    if tool == "Tab" or tool == "tab" then
      tool = "App"
    end

    -- No process identity detected: any dynamic desk-roots route is displayable.
    if tool == "Shell" or tool == "App" then
      local agent_root = desk.get_tab_desk_by_id(tab.tab_id)
      local agent = agent_root and desk.agent_for_path(agent_root) or nil
      if agent and agent ~= "" and agent ~= "shell" then
        tool = route_label(agent)
      end
    end

    -- Pure navigation label (our only customization). Length does not depend on activity.
    local label
    if project and project ~= "" and tool ~= "Init" and tool ~= "Help" and tool ~= "Files" then
      label = project .. " | " .. tool
    else
      label = tool
    end
    local body = " " .. label .. " "

    -- Stock WezTerm activity: has_unseen_output → Bold + brighter fg (same text).
    -- No extra glyphs, no orange skin, no per-tick rewrite → no tab width thrash.
    local unseen = tab_has_unseen_output(tab, pane, panes)

    if tab.is_active then
      return {
        { Background = { Color = C.tab_on_bg } },
        { Foreground = { Color = C.tab_on_fg } },
        { Attribute = { Intensity = "Bold" } },
        { Text = body },
      }
    end
    if hover then
      return {
        { Background = { Color = C.tab_hover_bg } },
        { Foreground = { Color = C.tab_hover_fg } },
        { Text = body },
      }
    end
    if unseen then
      -- Equivalent to WezTerm default "this tab needs attention"
      return {
        { Background = { Color = C.tab_unseen_bg } },
        { Foreground = { Color = C.tab_unseen_fg } },
        { Attribute = { Intensity = "Bold" } },
        { Text = body },
      }
    end
    return {
      { Background = { Color = C.tab_off_bg } },
      { Foreground = { Color = C.tab_off_fg } },
      { Text = body },
    }
  end)

  wezterm.on("gui-startup", function(cmd)
    local mux = wezterm.mux
    local resume = require("workbench.resume")
    local tab, pane, window
    if resume.should_bootstrap_on_startup(cmd) then
      tab, pane, window = mux.spawn_window({
        args = resume.bootstrap_args(),
        cwd = wezterm.home_dir,
      })
      if tab then
        pcall(function()
          -- Navigation-only title (never a filesystem path)
          tab:set_title("Init")
        end)
      end
    else
      tab, pane, window = mux.spawn_window(cmd or {})
    end
    local gui = window:gui_window()
    if gui then
      local n = 0
      pcall(function()
        for _ in pairs(mux.all_windows()) do
          n = n + 1
        end
      end)
      if n <= 1 then
        gui:maximize()
      end
    end
  end)
end

return M
