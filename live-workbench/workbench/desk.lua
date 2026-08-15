-- AI STAR CUBE · per-TAB task root (NOT a single global project)
--
-- ============================================================================
-- HARD RULES (gates · keep in sync with bootstrap.ps1)
-- ============================================================================
-- R1  AI sessions for real work MUST launch on a strong project path
--     (grok: --cwd; codex: -C/--cd; kimi: process cwd only — no cwd flag).
--     Shell `cd` never becomes the session identity.
-- R2  Weak / system paths are NEVER a project root:
--     USERPROFILE, Desktop, Documents root, Downloads, AppData, Temp, Windows.
-- R3  「项目名」= desk-roots.tsv LEFT column (binding name), NOT session title,
--     NOT Grok generated_title, NOT raw cwd leaf (esp. not "home" / "Desktop").
-- R4  「项目路径」= desk-roots.tsv RIGHT column; frozen at create/bind time.
--     Optional marker file at <path>\.wz-project reinforces name+path.
-- R5  set_root / bind refuse weak paths (no clobber of strong with weak either).
-- R6  Prefer reverse-lookup name_for_path(path) everywhere UI shows "Project".
--
-- Each tab has its own "任务根". Opening tabs A/B/C = three independent roots.
-- Status bar only describes the active tab.
--
-- How a tab GETS a task root (binding sources, highest first):
--   1) Explicit per-tab memory (F9/F6/resume/open-project/F7 bind)
--   2) Live panes ON THIS TAB with a strong project cwd (esp. Grok --cwd)
--   3) Focused pane strong cwd (if not init-panel / explorer noise)
--   4) Otherwise: unbound — do NOT inherit another tab via window workspace

local wezterm = require("wezterm")

local M = {}

local home = wezterm.home_dir
local roots_file = home .. "\\.config\\wezterm\\workbench\\desk-roots.tsv"

function M.normalize(path)
  if not path or path == "" then
    return nil
  end
  path = tostring(path)
  -- Strip file:// / file:/// prefixes (WezTerm Url / cli list)
  path = path:gsub("^file:///", ""):gsub("^file://", "")
  path = path:gsub("^file:\\+", ""):gsub("^file:", "")
  -- URL-encoded spaces etc. (best-effort)
  path = path:gsub("%%20", " ")
  path = path:gsub("/", "\\")
  -- ///G:\foo or \G:\foo → G:\foo
  path = path:gsub("^\\+([A-Za-z]:)", "%1")
  path = path:gsub("^/([A-Za-z]:)", "%1")
  path = path:gsub("\\+$", "")
  if path == "" then
    return nil
  end
  return path
end

function M.basename(path)
  path = M.normalize(path)
  if not path then
    return "?"
  end
  return path:match("([^/\\]+)$") or path
end

function M.short_path(path, max_len)
  path = M.normalize(path)
  if not path then
    return "—"
  end
  max_len = max_len or 36
  local h = home
  if h and path:sub(1, #h):lower() == h:lower() then
    path = "~" .. path:sub(#h + 1)
  end
  if #path <= max_len then
    return path
  end
  return "…" .. path:sub(-(max_len - 1))
end

function M.path_under(child, root)
  child = M.normalize(child)
  root = M.normalize(root)
  if not child or not root then
    return false
  end
  local a, b = child:lower(), root:lower()
  if a == b then
    return true
  end
  return a:sub(1, #b + 1) == b .. "\\"
end

--- Reserved binding names that must never be treated as real projects
local RESERVED_NAMES = {
  home = true,
  desktop = true,
  documents = true,
  downloads = true,
  ["my documents"] = true,
  administrator = true,
  users = true,
  temp = true,
  tmp = true,
  appdata = true,
  windows = true,
  system32 = true,
  config = true,
  [".config"] = true,
  wezterm = true,
}

function M.is_reserved_name(name)
  if not name or name == "" then
    return true
  end
  return RESERVED_NAMES[tostring(name):lower()] == true
end

--- Paths that must never be a task / project root (R2)
function M.is_weak_path(path)
  path = M.normalize(path)
  if not path or path == "" then
    return true
  end
  local pl = path:lower()
  local hl = (home or ""):lower()
  if hl ~= "" then
    if pl == hl then
      return true
    end
    -- Exact profile shortcuts (not children of Desktop\MyProject)
    local weak_exact = {
      hl .. "\\desktop",
      hl .. "\\documents",
      hl .. "\\downloads",
      hl .. "\\pictures",
      hl .. "\\music",
      hl .. "\\videos",
      hl .. "\\onedrive",
      hl .. "\\.config",
      hl .. "\\.config\\wezterm",
    }
    for _, w in ipairs(weak_exact) do
      if pl == w then
        return true
      end
    end
    -- Whole trees that are never project roots
    if pl:sub(1, #hl + 9) == hl .. "\\appdata" then
      return true
    end
    -- Any hidden directory directly below the user profile is tool/config
    -- state by default. This open rule protects future Agent homes without a
    -- product-name list; real projects belong under an explicit strong root.
    local rel = pl:sub(#hl + 2)
    if rel:match("^%.[^\\]+") then
      return true
    end
  end
  if pl:match("\\windows\\(system32|syswow64)") then
    return true
  end
  if pl:match("\\appdata\\local\\temp") or pl:match("\\windows\\temp") then
    return true
  end
  -- Drive root alone (C:\) is not a project
  if pl:match("^[a-z]:$") then
    return true
  end
  -- malformed leftovers
  if pl:match("^\\+[a-z]:") then
    return true
  end
  return false
end

function M.is_strong_path(path)
  path = M.normalize(path)
  if not path then
    return false
  end
  return not M.is_weak_path(path)
end

local function path_from_url_or_string(cwd)
  if not cwd then
    return nil
  end
  if type(cwd) == "string" then
    return M.normalize(cwd)
  end
  if type(cwd) == "table" then
    if cwd.file_path and #cwd.file_path > 0 then
      return M.normalize(cwd.file_path)
    end
    if cwd.path and #tostring(cwd.path) > 0 then
      return M.normalize(cwd.path)
    end
  end
  return nil
end

--- Parse `grok --cwd <path>` from argv list
local function cwd_from_argv(argv)
  if not argv then
    return nil
  end
  local i = 1
  local n = #argv
  while i <= n do
    local a = tostring(argv[i] or "")
    if a == "--cwd" or a == "-C" then
      local nextv = argv[i + 1]
      if nextv then
        return M.normalize(tostring(nextv))
      end
    end
    local m = a:match("^%-%-cwd=(.+)$") or a:match("^%-C=(.+)$")
    if m then
      return M.normalize(m)
    end
    i = i + 1
  end
  return nil
end

function M.process_info(pane)
  if not pane then
    return nil
  end
  local ok, info = pcall(function()
    return pane:get_foreground_process_info()
  end)
  if ok then
    return info
  end
  return nil
end

function M.process_name(pane)
  local info = M.process_info(pane)
  if info and info.name and info.name ~= "" then
    return tostring(info.name)
  end
  if info and info.executable and info.executable ~= "" then
    return tostring(info.executable)
  end
  if not pane then
    return ""
  end
  local ok, name = pcall(function()
    return pane:get_foreground_process_name() or ""
  end)
  if ok and name then
    return tostring(name)
  end
  return ""
end

-- Forward declaration: the parser-backed implementation is assigned below;
-- process helpers can call it after module initialization without a cycle.
local read_agent_map

local function dynamic_agent_id_for_process(name)
  if not name or name == "" then
    return nil
  end
  local leaf = tostring(name):lower():gsub("/", "\\"):match("([^\\]+)$") or tostring(name):lower()
  leaf = leaf:gsub("%.exe$", ""):gsub("%.com$", ""):gsub("%.cmd$", ""):gsub("%.bat$", ""):gsub("%.ps1$", "")
  local ids = {}
  local live = wezterm.GLOBAL.wz_agent_route_ids
  if type(live) == "table" then
    for _, id in ipairs(live) do
      ids[tostring(id):lower()] = true
    end
  end
  -- Bound route ids are available before the first runtime discovery action.
  local agents = read_agent_map and read_agent_map() or nil
  if type(agents) == "table" then
    for _, id in pairs(agents) do
      ids[tostring(id):lower()] = true
    end
  end
  for id in pairs(ids) do
    if leaf == id then
      return id
    end
  end
  return nil
end

function M.is_ai_process(name)
  return dynamic_agent_id_for_process(name) ~= nil
end

function M.is_explorer_process(name, pane)
  if name and name ~= "" then
    local n = name:lower()
    if
      n:find("sidebar", 1, true)
      or n:find("ai explorer", 1, true)
      or (n:find("explorer", 1, true) and not n:find("iexplore", 1, true))
    then
      return true
    end
  end
  if pane then
    local info = M.process_info(pane)
    if info and info.argv then
      for _, a in ipairs(info.argv) do
        local s = tostring(a):lower()
        if
          s:find("sidebar.ps1", 1, true)
          or s:find("cheatsheet", 1, true)
          or s:find("bootstrap.ps1", 1, true)
        then
          return true
        end
      end
    end
  end
  return false
end

--- Init panel / bootstrap is not a "project" — never treat its cwd as task root
function M.is_workbench_utility_pane(pane)
  if not pane then
    return false
  end
  if M.is_explorer_process(M.process_name(pane), pane) then
    return true
  end
  local info = M.process_info(pane)
  if info and info.argv then
    for _, a in ipairs(info.argv) do
      local s = tostring(a):lower()
      if s:find("bootstrap.ps1", 1, true) or s:find("wz-init", 1, true) then
        return true
      end
    end
  end
  return false
end

--- Best-effort task root path for a single pane
function M.cwd_from_pane(pane)
  if not pane then
    return home
  end

  local info = M.process_info(pane)
  if info then
    local from_argv = cwd_from_argv(info.argv)
    if M.is_strong_path(from_argv) then
      return from_argv
    end
    local from_info = M.normalize(info.cwd)
    if M.is_strong_path(from_info) then
      return from_info
    end
  end

  local ok, cwd = pcall(function()
    return pane:get_current_working_dir()
  end)
  if ok then
    local p = path_from_url_or_string(cwd)
    if p then
      return p
    end
  end

  if info and info.cwd then
    local p = M.normalize(info.cwd)
    if p then
      return p
    end
  end
  return home
end

--- Scan active tab: prefer AI pane strong cwd, else any strong non-explorer cwd
function M.best_task_root_in_tab(window, pane)
  local best_ai = nil
  local best_any = nil

  local function consider(p)
    if not p then
      return
    end
    local proc = M.process_name(p)
    if M.is_explorer_process(proc, p) then
      return
    end
    local cwd = M.cwd_from_pane(p)
    if not M.is_strong_path(cwd) then
      return
    end
    if M.is_ai_process(proc) then
      best_ai = cwd
    elseif not best_any then
      best_any = cwd
    end
  end

  pcall(function()
    local tab = nil
    -- Prefer explicitly active tab from mux (correct on tab switch)
    if window then
      pcall(function()
        local mux = window:mux_window()
        if mux then
          for _, ti in ipairs(mux:tabs_with_info() or {}) do
            if ti and ti.is_active and ti.tab then
              tab = ti.tab
              break
            end
          end
        end
      end)
      if not tab then
        pcall(function()
          tab = window:active_tab()
        end)
      end
    end
    if not tab and pane then
      pcall(function()
        tab = pane:tab()
      end)
    end
    if tab then
      local panes_ok, panes = pcall(function()
        return tab:panes()
      end)
      if panes_ok and panes then
        for _, p in ipairs(panes) do
          consider(p)
          if best_ai then
            break
          end
        end
      else
        local info_ok, infos = pcall(function()
          return tab:panes_with_info()
        end)
        if info_ok and infos then
          for _, pi in ipairs(infos) do
            if pi.pane then
              consider(pi.pane)
              if best_ai then
                break
              end
            end
          end
        end
      end
    end
  end)

  -- Always also consider focused pane (active_pane preferred by caller)
  consider(pane)

  return best_ai or best_any
end

--- desk-roots.tsv readers (D-004: optional 3rd TAB column = agent).
--- M-2: HUD (update-status 500ms) + format-tab-title call these per repaint;
--- a short TTL cache collapses repeat file IO to ~1 read/sec. WRITE paths
--- (set_root/write_map) always parse FRESH so a rewrite never resurrects or
--- clobbers rows written by sidebar.ps1/bootstrap.ps1 inside the TTL window.
local roots_cache = { t = 0, map = nil, agents = nil }
local ROOTS_CACHE_TTL_SEC = 2

local function parse_roots()
  local map, agents = {}, {}
  local f = io.open(roots_file, "r")
  if not f then
    -- Crash recovery for the two-rename transaction in write_map.
    f = io.open(roots_file .. ".bak", "r")
    if not f then
      return map, agents
    end
  end
  for line in f:lines() do
    -- strip UTF-8 BOM
    line = line:gsub("^\239\187\191", "")
    line = line:match("^%s*(.-)%s*$") or ""
    if line ~= "" and not line:match("^#") then
      -- 2 or 3 TAB columns: agent (if any) must NOT bleed into the path
      local ws, path, agent = line:match("^([^\t]+)\t+([^\t]+)\t+(.+)$")
      if not ws then
        ws, path = line:match("^([^\t]+)\t+([^\t]+)")
      end
      if not ws then
        ws, path = line:match("^(%S+)%s+(.+)$")
      end
      if ws and path then
        path = M.normalize(path)
        -- R2/R5: drop reserved names and weak paths from task map
        if path and M.is_strong_path(path) and not M.is_reserved_name(ws) then
          map[ws] = path
        end
        if agent then
          agent = agent:match("^%s*(.-)%s*$") or ""
          if agent ~= "" then
            agents[ws] = agent:lower()
          end
        end
      end
    end
  end
  f:close()
  return map, agents
end

local function read_map(fresh)
  if not fresh then
    local now = os.time()
    if roots_cache.map and (now - roots_cache.t) < ROOTS_CACHE_TTL_SEC then
      return roots_cache.map
    end
  end
  local map, agents = parse_roots()
  roots_cache.t = os.time()
  roots_cache.map = map
  roots_cache.agents = agents
  return map
end

read_agent_map = function()
  if roots_cache.agents and (os.time() - roots_cache.t) < ROOTS_CACHE_TTL_SEC then
    return roots_cache.agents
  end
  read_map()
  return roots_cache.agents
end

local function write_map(map)
  -- Parent dir is ~/.config/wezterm/workbench (created by install).
  -- Do NOT use wezterm.run_child_process for mkdir: even at event-time it is
  -- heavy; at config-load it is fatal ("yield across a C-call boundary").
  -- If the directory is missing, io.open fails and caller can toast.
  -- D-005: read existing agent column BEFORE truncating so rewrites keep it —
  -- FRESH parse, never the cache (a sidebar write inside the TTL would be lost).
  local _, agents = parse_roots()
  local lines = {
    "# AI STAR CUBE desk roots — project_name<TAB>absolute_path[<TAB>agent]",
    "# 项目名(绑定名) 与 项目路径 的写死绑定；Explorer / 状态栏 / F6 / Init 共用",
    "# 弱路径(home/Desktop/…)与保留名不得写入；创建项目时一次写死",
    "# 第三列 route id 来自开放式 Agent 探测；未绑定时保留两列",
  }
  local keys = {}
  for k in pairs(map) do
    table.insert(keys, k)
  end
  table.sort(keys)
  for _, ws in ipairs(keys) do
    local p = M.normalize(map[ws])
    if p and M.is_strong_path(p) and not M.is_reserved_name(ws) then
      local a = agents[ws]
      if a and a ~= "" then
        table.insert(lines, ws .. "\t" .. p .. "\t" .. a)
      else
        table.insert(lines, ws .. "\t" .. p)
      end
    end
  end
  -- Recoverable two-rename transaction. Windows cannot rename over an
  -- existing file; deleting the target first created a crash window where all
  -- bindings vanished. Keep the old file as .bak until the new file is live.
  local tmp = roots_file .. ".tmp"
  local bak = roots_file .. ".bak"
  local f = io.open(tmp, "w")
  if not f then
    return false
  end
  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()
  os.remove(bak)
  local old = io.open(roots_file, "r")
  if old then
    old:close()
    local moved_old = os.rename(roots_file, bak)
    if not moved_old then
      os.remove(tmp)
      return false
    end
  end
  local ok = os.rename(tmp, roots_file)
  if not ok then
    -- Restore the previous known-good file; leave no half-written target.
    os.rename(bak, roots_file)
    os.remove(tmp)
  else
    os.remove(bak)
  end
  if ok then
    -- cache is now exactly what we wrote
    roots_cache.t = os.time()
    roots_cache.map = map
    roots_cache.agents = agents
  end
  return ok and true or false
end

--- Agent route for a binding name; nil means caller must use discovery default.
function M.agent_for_name(name)
  if not name or name == "" then
    return nil
  end
  return read_agent_map()[name]
end

--- Agent route for a task root path; nil means caller must use discovery default.
function M.agent_for_path(path)
  local name = M.name_for_path(path)
  if not name then
    return nil
  end
  return M.agent_for_name(name)
end

--- Reverse lookup: absolute path → desk-roots binding name (R3 / R6)
function M.name_for_path(path)
  path = M.normalize(path)
  if not path then
    return nil
  end
  local map = read_map()
  local pl = path:lower()
  for name, p in pairs(map) do
    local np = M.normalize(p)
    if np and np:lower() == pl then
      return name
    end
  end
  local best_name, best_len = nil, -1
  for name, p in pairs(map) do
    local np = M.normalize(p)
    if np then
      local nl = np:lower()
      if pl == nl or pl:sub(1, #nl + 1) == nl .. "\\" then
        if #nl > best_len then
          best_len = #nl
          best_name = name
        end
      end
    end
  end
  if best_name then
    return best_name
  end
  local marker = path .. "\\.wz-project"
  local f = io.open(marker, "r")
  if f then
    for line in f:lines() do
      local n = line:match("^%s*name%s*=%s*(%S+)")
      if n and not M.is_reserved_name(n) then
        f:close()
        return n
      end
    end
    f:close()
  end
  if M.is_strong_path(path) then
    local leaf = M.basename(path)
    if leaf and not M.is_reserved_name(leaf) then
      return leaf
    end
  end
  return nil
end

--- Canonical project display name for a path (never "home")
function M.project_label(path)
  local n = M.name_for_path(path)
  if n then
    return n
  end
  if M.is_weak_path(path) then
    return "(system)"
  end
  return M.basename(path) or "?"
end

function M.get_root(workspace)
  if not workspace or workspace == "" then
    return nil
  end
  if M.is_reserved_name(workspace) then
    return nil
  end
  local g = wezterm.GLOBAL.star_cube_desk
  if g and g[workspace] then
    local p = M.normalize(g[workspace])
    if p and M.is_strong_path(p) then
      return p
    end
  end
  local map = read_map()
  return map[workspace]
end

function M.set_root(workspace, path)
  workspace = workspace and tostring(workspace):match("^%s*(.-)%s*$")
  path = M.normalize(path)
  if not workspace or workspace == "" or not path then
    return false
  end
  -- R5: never bind reserved names or weak paths as projects
  if M.is_reserved_name(workspace) then
    return false
  end
  if M.is_weak_path(path) then
    return false
  end

  wezterm.GLOBAL.star_cube_desk = wezterm.GLOBAL.star_cube_desk or {}
  local prev = M.normalize(wezterm.GLOBAL.star_cube_desk[workspace]) or M.get_root(workspace)

  if prev and prev == path then
    wezterm.GLOBAL.star_cube_desk[workspace] = path
    return true
  end

  local map = read_map(true) -- FRESH: a write path must see concurrent file writes
  -- same path already under another name → keep one binding (caller name wins)
  local pl = path:lower()
  for k, p in pairs(map) do
    if k ~= workspace and M.normalize(p) and M.normalize(p):lower() == pl then
      map[k] = nil
    end
  end
  if map[workspace] == path then
    wezterm.GLOBAL.star_cube_desk[workspace] = path
    return true
  end
  map[workspace] = path
  wezterm.GLOBAL.star_cube_desk[workspace] = path
  return write_map(map)
end

function M.active_workspace(window)
  if not window then
    return "home"
  end
  local ok, name = pcall(function()
    return window:active_workspace()
  end)
  if ok and name and name ~= "" then
    return name
  end
  return "home"
end

--- MuxTab uses method tab_id(); TabInformation uses field tab_id.
--- Never assume one shape — wrong call is swallowed by pcall and becomes "stuck path".
local function extract_tab_id(tab)
  if not tab then
    return nil
  end
  -- Try field first (TabInformation in format-tab-title) — number/string
  local ok_field, field = pcall(function()
    return tab.tab_id
  end)
  if ok_field and field ~= nil and type(field) ~= "function" then
    if type(field) == "number" or type(field) == "string" then
      return field
    end
  end
  -- MuxTab method
  local ok_m, v = pcall(function()
    return tab:tab_id()
  end)
  if ok_m and v ~= nil and tostring(v) ~= "" then
    return v
  end
  return nil
end

M.extract_tab_id = extract_tab_id

--- Tab that OWNS this pane (use for WRITE / bind). Do NOT use active_tab here:
--- after spawn_tab the focused tab can still briefly be the previous one.
local function tab_id_for_pane(pane)
  if not pane then
    return nil
  end
  local id = nil
  pcall(function()
    id = extract_tab_id(pane:tab())
  end)
  if id then
    return id
  end
  -- pane_id secondary index (some builds pane:tab() is flaky at spawn)
  pcall(function()
    local pid = pane:pane_id()
    if pid and wezterm.GLOBAL.star_cube_pane_desk then
      -- no id from pane's tab; caller may still set pane index
    end
  end)
  return id
end

--- Clean project name from tab title decorations
function M.title_to_project_name(title)
  if not title or title == "" then
    return nil
  end
  local t = tostring(title)
  t = t:gsub("^★%s*", ""):gsub("^✦%s*", ""):gsub("^◎%s*", ""):gsub("^↩%s*", "")
  t = t:gsub("^检%s*", ""):gsub("^⚔%s*", "")
  t = t:gsub("%s+·%s+.*$", "") -- drop " · tool" if any
  t = t:match("^%s*(.-)%s*$") or t
  if t == "" or t == "选任务" or t == "初始化" then
    return nil
  end
  local low = t:lower()
  if low:find("powershell") or low:find("bootstrap") or t:find("%.exe") then
    return nil
  end
  return t
end

--- Snapshot of the GUI-active tab (id, title, mux tab object)
function M.active_tab_snapshot(window, pane)
  local snap = { id = nil, title = nil, tab = nil }
  if window then
    pcall(function()
      local mux = window:mux_window()
      if not mux then
        return
      end
      for _, ti in ipairs(mux:tabs_with_info() or {}) do
        if ti and ti.is_active then
          snap.tab = ti.tab
          snap.id = extract_tab_id(ti.tab)
          if ti.tab then
            pcall(function()
              snap.title = ti.tab:get_title()
            end)
          end
          -- TabInformation-style fields sometimes live on ti
          if not snap.id and ti.tab_id then
            snap.id = ti.tab_id
          end
          return
        end
      end
    end)
    if not snap.id then
      pcall(function()
        local t = window:active_tab()
        snap.tab = t
        snap.id = extract_tab_id(t)
        if t then
          pcall(function()
            snap.title = t:get_title()
          end)
        end
      end)
    end
    if not snap.id then
      pcall(function()
        local ap = window:active_pane()
        if ap then
          snap.id = tab_id_for_pane(ap)
        end
      end)
    end
  end
  if not snap.id then
    snap.id = tab_id_for_pane(pane)
  end
  return snap
end

--- Currently ACTIVE tab id in the GUI window (use for READ / status bar).
function M.active_tab_id(window, pane)
  return M.active_tab_snapshot(window, pane).id
end

function M.get_tab_desk_by_id(tab_id)
  if not tab_id then
    return nil
  end
  local g = wezterm.GLOBAL.star_cube_tab_desk
  if not g then
    return nil
  end
  return M.normalize(g[tostring(tab_id)])
end

function M.set_tab_desk_by_id(tab_id, path)
  path = M.normalize(path)
  if not tab_id or not path then
    return false
  end
  -- R5: weak path never becomes tab desk if a strong one already exists
  if M.is_weak_path(path) then
    return false
  end
  wezterm.GLOBAL.star_cube_tab_desk = wezterm.GLOBAL.star_cube_tab_desk or {}
  local key = tostring(tab_id)
  wezterm.GLOBAL.star_cube_tab_desk[key] = path
  -- index by binding name (desk-roots), not raw leaf (avoids "home")
  local name = M.name_for_path(path) or M.basename(path)
  if name and name ~= "" and not M.is_reserved_name(name) then
    M.set_root(name, path)
  end
  return true
end

--- Prefer binding via MuxTab object (spawn_tab returns it — most reliable id)
function M.bind_tab(tab, path, pane)
  path = M.normalize(path)
  if not path then
    return false
  end
  local id = extract_tab_id(tab)
  if not id then
    id = tab_id_for_pane(pane)
  end
  if not id then
    return false
  end
  local ok = M.set_tab_desk_by_id(id, path)
  -- pane_id secondary map: every pane in this tab points at same root
  if pane then
    pcall(function()
      wezterm.GLOBAL.star_cube_pane_desk = wezterm.GLOBAL.star_cube_pane_desk or {}
      wezterm.GLOBAL.star_cube_pane_desk[tostring(pane:pane_id())] = path
    end)
  end
  if tab then
    pcall(function()
      for _, p in ipairs(tab:panes() or {}) do
        wezterm.GLOBAL.star_cube_pane_desk = wezterm.GLOBAL.star_cube_pane_desk or {}
        wezterm.GLOBAL.star_cube_pane_desk[tostring(p:pane_id())] = path
      end
    end)
  end
  return ok
end

function M.get_tab_desk(window, pane)
  local snap = M.active_tab_snapshot(window, pane)
  local by_id = M.get_tab_desk_by_id(snap.id)
  if M.is_strong_path(by_id) then
    return by_id
  end
  -- title → name map (survives bad tab_id writes)
  local pname = M.title_to_project_name(snap.title)
  if pname then
    local by_title = M.get_root(pname)
    if M.is_strong_path(by_title) then
      if snap.id then
        M.set_tab_desk_by_id(snap.id, by_title)
      end
      return by_title
    end
  end
  -- pane secondary
  if pane then
    local ok, pid = pcall(function()
      return pane:pane_id()
    end)
    if ok and pid and wezterm.GLOBAL.star_cube_pane_desk then
      local by_pane = M.normalize(wezterm.GLOBAL.star_cube_pane_desk[tostring(pid)])
      if M.is_strong_path(by_pane) then
        return by_pane
      end
    end
  end
  return by_id
end

function M.set_tab_desk(window, pane, path)
  path = M.normalize(path)
  if not path then
    return false
  end
  -- WRITE: bind to the pane's own tab (new project tab / F9 spawn), not active_tab
  local id = tab_id_for_pane(pane)
  if not id then
    id = M.active_tab_id(window, pane)
  end
  if not id then
    -- last resort: still index by pane so status can recover
    if pane then
      pcall(function()
        wezterm.GLOBAL.star_cube_pane_desk = wezterm.GLOBAL.star_cube_pane_desk or {}
        wezterm.GLOBAL.star_cube_pane_desk[tostring(pane:pane_id())] = path
      end)
    end
    return false
  end
  local ok = M.set_tab_desk_by_id(id, path)
  if pane then
    pcall(function()
      wezterm.GLOBAL.star_cube_pane_desk = wezterm.GLOBAL.star_cube_pane_desk or {}
      wezterm.GLOBAL.star_cube_pane_desk[tostring(pane:pane_id())] = path
    end)
  end
  return ok
end

--- HUD-only resolve: always the GUI-active tab. Returns name, root, source, bound, tab_id
function M.resolve_active_for_hud(window, pane)
  local snap = M.active_tab_snapshot(window, pane)
  local tab_id = snap.id

  -- 1) per-tab memory
  local root = M.get_tab_desk_by_id(tab_id)
  if M.is_strong_path(root) then
    return M.project_label(root), root, "tab-mem", true, tab_id
  end

  -- 2) title → desk-roots name map
  local pname = M.title_to_project_name(snap.title)
  if pname and not M.is_reserved_name(pname) then
    local by_title = M.get_root(pname)
    if M.is_strong_path(by_title) then
      if tab_id then
        M.set_tab_desk_by_id(tab_id, by_title)
      end
      return M.project_label(by_title), by_title, "tab-title", true, tab_id
    end
  end

  -- 3) pane secondary map for active pane
  if pane then
    local ok, pid = pcall(function()
      return pane:pane_id()
    end)
    if ok and pid and wezterm.GLOBAL.star_cube_pane_desk then
      local by_pane = M.normalize(wezterm.GLOBAL.star_cube_pane_desk[tostring(pid)])
      if M.is_strong_path(by_pane) then
        if tab_id then
          M.set_tab_desk_by_id(tab_id, by_pane)
        end
        return M.project_label(by_pane), by_pane, "pane-mem", true, tab_id
      end
    end
  end

  -- 4) live scan + focused cwd (same rules as resolve_tab_task)
  local scanned = M.best_task_root_in_tab(window, pane)
  if M.is_strong_path(scanned) then
    if tab_id then
      M.set_tab_desk_by_id(tab_id, scanned)
    end
    return M.project_label(scanned), scanned, "tab-scan", true, tab_id
  end

  local pane_cwd = M.cwd_from_pane(pane)
  local proc = M.process_name(pane)
  local utility = M.is_workbench_utility_pane(pane)
  if
    M.is_strong_path(pane_cwd)
    and not utility
    and not M.is_explorer_process(proc, pane)
  then
    if tab_id then
      M.set_tab_desk_by_id(tab_id, pane_cwd)
    end
    return M.project_label(pane_cwd), pane_cwd, "pane", true, tab_id
  end

  return "未选定", nil, "unbound", false, tab_id
end

function M.bind(window, pane, path, opts)
  opts = opts or {}
  path = M.normalize(path) or M.cwd_from_pane(pane)
  if M.is_weak_path(path) then
    local better = M.best_task_root_in_tab(window, pane)
    if better then
      path = better
    end
  end
  if M.is_weak_path(path) then
    return nil, nil
  end
  local name = opts.workspace_name or M.name_for_path(path) or M.basename(path)
  if M.is_reserved_name(name) then
    name = M.basename(path)
  end
  local ws = M.active_workspace(window)

  if opts.rename_workspace then
    pcall(function()
      if ws and name and ws ~= name and M.is_strong_path(path) then
        wezterm.mux.rename_workspace(ws, name)
        ws = name
      end
    end)
  end

  M.set_root(name, path)
  M.set_tab_desk(window, pane, path)
  return name, path
end

--- Resolve the project for the ACTIVE TAB only.
--- Returns: task_name, root_path, source, bound (bool: has real task root)
---
--- source values:
---   tab-mem   = user/action bound this tab (F9/F6/resume/…)
---   tab-scan  = inferred from Grok/shell on this tab
---   pane      = focused strong cwd
---   unbound   = this tab has no task root yet (e.g. brand-new init panel tab)
function M.resolve_tab_task(window, pane)
  local tab_desk = M.get_tab_desk(window, pane)
  local scanned = M.best_task_root_in_tab(window, pane)
  local pane_cwd = M.cwd_from_pane(pane)
  local proc = M.process_name(pane)
  local utility = M.is_workbench_utility_pane(pane)

  local root, source = nil, nil

  -- 1) Explicit per-tab memory first (user chose this tab's project)
  if M.is_strong_path(tab_desk) then
    root, source = tab_desk, "tab-mem"
  end

  -- 2) Live Grok/shell on THIS tab (only if no explicit mem, or scan is under mem)
  if M.is_strong_path(scanned) then
    if not root then
      root, source = scanned, "tab-scan"
    end
  end

  -- 3) Focused strong cwd — never from init panel / explorer alone
  if
    not root
    and M.is_strong_path(pane_cwd)
    and not utility
    and not M.is_explorer_process(proc, pane)
  then
    root, source = pane_cwd, "pane"
  end

  -- 4) NO window-workspace / desk-roots fallback here.
  --    That map is shared by the whole window and made new tabs "inherit"
  --    WZ_Skill while the pane is still at ~\ — false "left project" warnings.

  if not M.is_strong_path(root) then
    -- Unbound tab (new + init panel, empty shell, etc.)
    return "未选定", nil, "unbound", false
  end

  root = M.normalize(root)
  local name = M.project_label(root)

  -- Persist only when we have a real project root for this tab
  if source == "tab-scan" or source == "pane" then
    M.set_tab_desk(window, pane, root)
    if name and not M.is_reserved_name(name) then
      M.set_root(name, root)
    end
  end

  return name, root, source or "?", true
end

--- Resolve task identity for actions (F7/F6). Returns name, root, source
function M.sync_from_pane(window, pane, opts)
  opts = opts or {}
  local name, root, source, bound = M.resolve_tab_task(window, pane)

  -- Actions that need a directory (F6/F7) may fall back to desk-roots / cwd
  if not bound or not M.is_strong_path(root) then
    local pane_cwd = M.cwd_from_pane(pane)
    if M.is_strong_path(pane_cwd) and not M.is_workbench_utility_pane(pane) then
      root = pane_cwd
      name = M.project_label(root)
      source = "ensure-pane"
      bound = true
    end
    if bound and M.is_strong_path(root) then
      M.set_tab_desk(window, pane, root)
      if name and not M.is_reserved_name(name) then
        M.set_root(name, root)
      end
    end
  end

  if opts.rename_workspace and M.is_strong_path(root) then
    local ws = M.active_workspace(window)
    if ws and name and ws ~= name and not M.is_reserved_name(name) then
      pcall(function()
        wezterm.mux.rename_workspace(ws, name)
      end)
    end
  end

  return name, root, source, bound
end

function M.resolve(window, pane)
  local name, root, source, bound = M.resolve_tab_task(window, pane)
  return root, name, source, bound
end

function M.ensure(window, pane)
  local name, root = M.sync_from_pane(window, pane, { rename_workspace = false })
  return name, root
end

function M.role_for_process(name)
  if not name then
    return "shell"
  end
  name = name:lower()
  local agent = dynamic_agent_id_for_process(name)
  if agent then
    local label = agent:gsub("[-_]", " "):gsub("(%a)([%w']*)", function(first, rest)
      return first:upper() .. rest
    end)
    return "AI·" .. label
  end
  if name:find("cheatsheet") then
    return "help"
  end
  if name:find("sidebar") or name:find("explorer") then
    return "Explorer"
  end
  if name:find("powershell") or name:find("pwsh") then
    return "shell"
  end
  return name:match("([^/\\]+)$") or "pane"
end

return M
