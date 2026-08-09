-- AI STAR CUBE · project picker + explorer + workspace switch
--
-- F9 must feel instant: never block on scanning huge folders.
-- Default list = desk-roots.tsv + favorites + fixed shortcuts.
-- Optional deep scan is a separate menu entry / Leader action.

local wezterm = require("wezterm")
local act = wezterm.action
local launch = require("workbench.launch")
local desk = require("workbench.desk")

local M = {}

local home = wezterm.home_dir
local favorites_file = home .. "\\.config\\wezterm\\workbench\\favorites.txt"
local roots_file = home .. "\\.config\\wezterm\\workbench\\desk-roots.tsv"
local sidebar_ps1 = home .. "\\.config\\wezterm\\workbench\\sidebar.ps1"

local SCAN_ROOTS = {
  home .. "\\Desktop",
  home .. "\\Documents",
  home .. "\\.config",
  home .. "\\.grok",
}

local FIXED = {
  { label = "[固定] Home", id = home },
  { label = "[固定] Desktop", id = home .. "\\Desktop" },
  { label = "[固定] Documents", id = home .. "\\Documents" },
  { label = "[固定] WezTerm config", id = home .. "\\.config\\wezterm" },
  { label = "[固定] .grok", id = home .. "\\.grok" },
}

local function basename(path)
  return desk.basename(path)
end

local function normalize(path)
  return desk.normalize(path)
end

local function toast(window, title, msg, ms)
  pcall(function()
    window:toast_notification(title, msg, nil, ms or 3500)
  end)
end

local function read_favorites()
  local list = {}
  local f = io.open(favorites_file, "r")
  if not f then
    return list
  end
  for line in f:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line and line ~= "" and not line:match("^#") then
      local p = normalize(line)
      if p then
        table.insert(list, p)
      end
    end
  end
  f:close()
  return list
end

local function read_desk_roots_list()
  -- { { name = ws, path = path }, ... }
  local list = {}
  local f = io.open(roots_file, "r")
  if not f then
    return list
  end
  for line in f:lines() do
    line = line:match("^%s*(.-)%s*$") or ""
    if line ~= "" and not line:match("^#") then
      local ws, path = line:match("^([^\t]+)\t+(.+)$")
      if not ws then
        ws, path = line:match("^(%S+)%s+(.+)$")
      end
      path = normalize(path)
      if ws and path then
        table.insert(list, { name = ws, path = path })
      end
    end
  end
  f:close()
  return list
end

local function scan_children(root)
  local out = {}
  root = normalize(root)
  if not root then
    return out
  end
  local esc = root:gsub("'", "''")
  local ok, stdout = wezterm.run_child_process({
    "powershell.exe",
    "-NoProfile",
    "-NonInteractive",
    "-Command",
    "if (Test-Path -LiteralPath '"
      .. esc
      .. "') { Get-ChildItem -LiteralPath '"
      .. esc
      .. "' -Directory -Force -ErrorAction SilentlyContinue | Select-Object -First 80 | ForEach-Object { $_.FullName } }",
  })
  if not ok or not stdout then
    return out
  end
  for line in tostring(stdout):gmatch("[^\r\n]+") do
    line = normalize(line)
    if line and #line > 0 then
      table.insert(out, line)
    end
  end
  return out
end

--- Fast list for F9 (no PowerShell folder scan)
function M.collect_choices_fast()
  local seen = {}
  local choices = {}

  local function add(label, id)
    id = normalize(id)
    if not id or seen[id:lower()] then
      return
    end
    seen[id:lower()] = true
    table.insert(choices, { label = label, id = id })
  end

  -- 1) Already-bound task projects (desk-roots) — only strong paths (R2)
  for _, item in ipairs(read_desk_roots_list()) do
    if desk.is_strong_path(item.path) and not desk.is_reserved_name(item.name) then
      add("[任务] " .. item.name .. "  →  " .. desk.short_path(item.path, 42), item.path)
    end
  end

  -- 2) Favorites (strong only)
  for _, fav in ipairs(read_favorites()) do
    if desk.is_strong_path(fav) then
      add("[收藏] " .. (desk.name_for_path(fav) or basename(fav)), fav)
    end
  end

  -- 3) Fixed places — browse only, NOT auto-bound as projects
  for _, item in ipairs(FIXED) do
    add(item.label .. "  (浏览，非项目)", item.id)
  end

  -- 4) Special command rows (handled in on_pick)
  add("…… 扫描 Desktop/Documents 更多文件夹 ……", "__SCAN__")
  add("…… 在已打开的任务工作区之间跳转 ……", "__WS_JUMP__")

  return choices
end

function M.collect_choices_scan()
  local choices = M.collect_choices_fast()
  -- drop the two specials at end before re-adding after scan
  local filtered = {}
  for _, c in ipairs(choices) do
    if c.id ~= "__SCAN__" and c.id ~= "__WS_JUMP__" then
      table.insert(filtered, c)
    end
  end
  choices = filtered

  local seen = {}
  for _, c in ipairs(choices) do
    seen[(c.id or ""):lower()] = true
  end

  local function add(label, id)
    id = normalize(id)
    if not id or seen[id:lower()] then
      return
    end
    seen[id:lower()] = true
    table.insert(choices, { label = label, id = id })
  end

  for _, root in ipairs(SCAN_ROOTS) do
    local kids = scan_children(root)
    local root_name = basename(root)
    for _, kid in ipairs(kids) do
      add(basename(kid) .. "  · " .. root_name, kid)
    end
  end

  add("…… 在已打开的任务工作区之间跳转 ……", "__WS_JUMP__")
  return choices
end

--- Enter project as a NEW TAB in the current window (tab-first).
---
--- Old behavior used SwitchToWorkspace, which swaps the whole tab set:
--- previous tabs disappeared until you jumped workspaces or closed the
--- "front" session. Users expected top-bar tabs side-by-side instead.
function M.open_as_workspace(window, pane, path)
  path = normalize(path)
  if not path then
    toast(window, "项目", "路径无效", 2500)
    return
  end
  -- R2/R5: system folders open as shell only — not a project bind
  if desk.is_weak_path(path) then
    toast(window, "非项目路径", "home/Desktop 等不能绑为项目 — 用 Init c 创建任务", 5000)
    local ok_w, err_w = pcall(function()
      local mux_window = window:mux_window()
      mux_window:spawn_tab({ cwd = path, args = launch.powershell })
    end)
    if not ok_w then
      toast(window, "打开失败", tostring(err_w), 3500)
    end
    return
  end
  local name = desk.name_for_path(path) or basename(path)
  -- Name→path map only. Do NOT rename mux workspace: one window holds many
  -- project tabs; window WS name is shared and must not impersonate one tab.
  desk.set_root(name, path)

  local ok, err = pcall(function()
    local mux_window = window:mux_window()
    local tab, main = mux_window:spawn_tab({
      cwd = path,
      args = launch.powershell,
    })
    if tab then
      tab:set_title(name)
    end
    if main then
      main:activate()
      -- bind via MuxTab object (reliable tab_id) + pane secondary index
      if not desk.bind_tab(tab, path, main) then
        desk.set_tab_desk(window, main, path)
      end
      desk.set_root(name, path)
    end
  end)

  if not ok then
    toast(window, "打开项目页签失败", tostring(err), 4500)
    return
  end

  toast(
    window,
    "新页签 · " .. name,
    "PATH="
      .. desk.short_path(path, 36)
      .. "  |  顶部页签并排  |  下一步 F6 开AI / F7 侧栏(严格绑本 PATH)",
    6500
  )
end

function M.open_as_workbench(window, pane, path)
  path = normalize(path)
  if not path then
    return
  end
  if desk.is_weak_path(path) then
    toast(window, "非项目路径", "不能在 home/Desktop 上开 AI 对话桌 — 先 F9 选真实项目", 5000)
    return
  end
  local name = desk.name_for_path(path) or basename(path)
  desk.set_root(name, path)

  local mux_window = window:mux_window()
  local tab, main = mux_window:spawn_tab({
    args = launch.grok_args(path),
    cwd = path,
  })

  local shell = main and main:split({
    direction = "Right",
    size = 0.30,
    args = launch.powershell,
    cwd = path,
  })

  if shell then
    local esc = path:gsub("'", "''")
    shell:split({
      direction = "Bottom",
      size = 0.42,
      args = launch.ps_command(
        "Write-Host '  == 本页签任务监视 ==' -ForegroundColor DarkCyan"
          .. "; Write-Host '  项目: "
          .. name:gsub("'", "''")
          .. "' -ForegroundColor Yellow"
          .. "; Write-Host '  根目录: "
          .. esc
          .. "' -ForegroundColor White"
          .. "; Write-Host '  顶栏「本页签」随标签切换 · F7 侧栏 · F9 换项目' -ForegroundColor DarkGray"
          .. "; if (Get-Command git -ErrorAction SilentlyContinue) { git -C '"
          .. esc
          .. "' status -sb 2>$null }"
      ),
      cwd = path,
    })
  end

  if tab then
    tab:set_title("✦ " .. name)
  end
  if main then
    main:activate()
    if not desk.bind_tab(tab, path, main) then
      desk.set_tab_desk(window, main, path)
    end
  end
  toast(window, "AI 对话桌 · 新页签", "本页签 → " .. name .. " · 顶栏随标签切换", 4000)
end

local function open_workspace_launcher(window, pane)
  toast(window, "工作区跳转", "选一个已打开的 WS（任务区）", 2500)
  window:perform_action(
    act.ShowLauncherArgs({
      flags = "FUZZY|WORKSPACES",
      title = "Jump workspace (task zone)",
    }),
    pane
  )
end

local function on_project_pick(window, pane, id, _)
  if not id or id == "" then
    toast(window, "项目", "已取消", 1500)
    return
  end
  if id == "__SCAN__" then
    toast(window, "项目", "正在扫描文件夹…", 2000)
    M.show_picker_scan(window, pane)
    return
  end
  if id == "__WS_JUMP__" then
    open_workspace_launcher(window, pane)
    return
  end
  M.open_as_workspace(window, pane, id)
end

local function run_input_selector(window, pane, title, choices)
  if not choices or #choices == 0 then
    toast(window, "项目", "列表为空 — 请检查 desk-roots.tsv", 4000)
    return
  end

  local ok, err = pcall(function()
    window:perform_action(
      act.InputSelector({
        title = title,
        fuzzy = true,
        fuzzy_description = "type to filter: ",
        choices = choices,
        action = wezterm.action_callback(on_project_pick),
      }),
      pane
    )
  end)

  if not ok then
    toast(window, "项目选择器失败", tostring(err), 5000)
    -- Fallback: workspace launcher at least works
    pcall(function()
      open_workspace_launcher(window, pane)
    end)
  end
end

--- F9: fast project picker (bound tasks + favorites + fixed)
function M.show_picker(window, pane)
  toast(window, "项目选择 F9", "↑↓ 选择  Enter 进入  Esc 取消  |  也可 Alt+z j 跳已开工作区", 4500)

  local ok, choices = pcall(M.collect_choices_fast)
  if not ok then
    toast(window, "Projects", "list failed: " .. tostring(choices), 4000)
    choices = {}
    for _, item in ipairs(FIXED) do
      table.insert(choices, { label = item.label, id = item.id })
    end
  end

  run_input_selector(
    window,
    pane,
    "F9 Project = bind WS+DESK  (Enter to switch)",
    choices
  )
end

--- Deep scan (slower): from menu row or Leader+.
function M.show_picker_scan(window, pane)
  local ok, choices = pcall(M.collect_choices_scan)
  if not ok or not choices then
    toast(window, "扫描失败", tostring(choices), 4000)
    return
  end
  toast(window, "扫描完成", "共 " .. tostring(#choices) .. " 项", 2000)
  run_input_selector(window, pane, "F9 scan · pick folder as project", choices)
end

function M.show_workbench_picker(window, pane)
  toast(window, "三栏 AI 桌", "选项目后直接开 Grok 三栏", 2500)
  local ok, choices = pcall(M.collect_choices_fast)
  if not ok or not choices or #choices == 0 then
    choices = {}
    for _, item in ipairs(FIXED) do
      table.insert(choices, { label = item.label, id = item.id })
    end
  end
  -- strip specials for workbench open
  local filtered = {}
  for _, c in ipairs(choices) do
    if c.id ~= "__SCAN__" and c.id ~= "__WS_JUMP__" then
      table.insert(filtered, c)
    end
  end

  window:perform_action(
    act.InputSelector({
      title = "Open 3-pane AI desk in project",
      fuzzy = true,
      fuzzy_description = "type to filter: ",
      choices = filtered,
      action = wezterm.action_callback(function(win, p, id, _)
        if id then
          M.open_as_workbench(win, p, id)
        end
      end),
    }),
    pane
  )
end

--- Jump among already-open WezTerm workspaces
function M.show_workspace_switcher(window, pane)
  open_workspace_launcher(window, pane)
end

--- Find an existing Explorer pane in the active tab (singleton rail).
local function find_explorer_pane(window)
  local ok, mux_win = pcall(function()
    return window:mux_window()
  end)
  if not ok or not mux_win then
    return nil
  end
  local ok_tabs, tab = pcall(function()
    return window:active_tab()
  end)
  if not ok_tabs or not tab then
    return nil
  end
  local ok_panes, panes = pcall(function()
    return tab:panes_with_info()
  end)
  if not ok_panes or not panes then
    return nil
  end
  for _, info in ipairs(panes) do
    local p = info.pane
    if p then
      local name = desk.process_name(p)
      if desk.is_explorer_process(name, p) then
        return p
      end
    end
  end
  return nil
end

--- Prefer splitting from the largest non-explorer pane (main stage), not focus.
local function host_pane_for_sidebar(window, fallback)
  local ok_tab, tab = pcall(function()
    return window:active_tab()
  end)
  if not ok_tab or not tab then
    return fallback
  end
  local ok_panes, panes = pcall(function()
    return tab:panes_with_info()
  end)
  if not ok_panes or not panes or #panes == 0 then
    return fallback
  end
  local best, best_area = nil, -1
  for _, info in ipairs(panes) do
    local p = info.pane
    if p then
      local name = desk.process_name(p)
      if not desk.is_explorer_process(name, p) and not desk.is_workbench_utility_pane(p) then
        local w = info.width or 0
        local h = info.height or 0
        local area = w * h
        if area > best_area then
          best_area = area
          best = p
        end
      end
    end
  end
  -- Prefer AI pane if present among large panes
  for _, info in ipairs(panes) do
    local p = info.pane
    if p and desk.is_ai_process(desk.process_name(p)) then
      local w = info.width or 0
      local h = info.height or 0
      if (w * h) >= (best_area * 0.5) then
        return p
      end
    end
  end
  return best or fallback
end

--- Left explorer — fixed left rail: singleton + split from main stage only.
function M.open_sidebar(window, pane)
  -- 1) Singleton: already open → focus + in-place refresh (no second split)
  local existing = find_explorer_pane(window)
  if existing then
    pcall(function()
      existing:activate()
    end)
    -- Send "r" + Enter so sidebar.ps1 reloads listing without F4/F7 recreation
    pcall(function()
      window:perform_action(act.SendString("r\r"), existing)
    end)
    toast(window, "Explorer", "已聚焦现有侧栏并刷新 (r) — 未新建分栏", 3500)
    return
  end

  local ws, root, source = desk.sync_from_pane(window, pane, {
    rename_workspace = false,
  })
  root = desk.normalize(root)

  if not desk.is_strong_path(root) then
    local scanned = desk.best_task_root_in_tab(window, pane)
    if desk.is_strong_path(scanned) then
      root = scanned
      source = "tab-scan-fallback"
    end
  end
  if not desk.is_strong_path(root) then
    local by_ws = desk.get_root(desk.active_workspace(window))
    if desk.is_strong_path(by_ws) then
      root = by_ws
      source = "bound-fallback"
    end
  end
  if not desk.is_strong_path(root) then
    local by_name = desk.get_root(ws)
    if desk.is_strong_path(by_name) then
      root = by_name
      source = "name-map"
    end
  end

  if not root then
    root = desk.cwd_from_pane(pane)
  end

  if desk.is_weak_path(root) then
    local fixed = desk.get_root("WZ_Skill") or desk.get_root(ws)
    if desk.is_strong_path(fixed) then
      root = fixed
      ws = desk.basename(fixed)
      source = "repaired-map"
    end
  end

  ws = desk.basename(root)
  if desk.is_weak_path(root) then
    toast(window, "Explorer", "无法解析项目根 — 请用 F9 选项目或 grok --cwd", 5000)
  end

  local start = root
  local host = host_pane_for_sidebar(window, pane)
  local pane_cwd = desk.cwd_from_pane(host)
  local proc = desk.process_name(host)
  if
    desk.is_strong_path(pane_cwd)
    and desk.path_under(pane_cwd, root)
    and not desk.is_explorer_process(proc, host)
  then
    start = pane_cwd
  end

  desk.set_tab_desk(window, host, root)
  local bind_name = desk.name_for_path(root) or ws
  if not desk.is_reserved_name(bind_name) then
    desk.set_root(bind_name, root)
  end
  ws = bind_name

  -- Always split from main-stage pane (not a tiny focused shell/explorer).
  -- size 0.21 ≈ 30% narrower than legacy 0.30 left rail.
  local side = host:split({
    direction = "Left",
    size = 0.21,
    args = {
      "powershell.exe",
      "-NoLogo",
      "-NoExit",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      sidebar_ps1,
      "-StartPath",
      start,
      "-DeskRoot",
      root,
      "-Workspace",
      ws,
    },
    cwd = start,
  })

  if side then
    side:activate()
  end
  toast(
    window,
    "Explorer · 左轨",
    "WS:"
      .. (ws or "?")
      .. "  DESK:"
      .. desk.short_path(root, 36)
      .. "  ["
      .. (source or "?")
      .. "]",
    4000
  )
end

return M
