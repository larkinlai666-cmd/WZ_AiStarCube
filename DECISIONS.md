# Authority and Decisions

## Active Authority Index

<!-- PPS:ACTIVE:BEGIN -->
- `M-001`
- `M-002`
- `M-003`
- `F-001`
- `F-002`
- `F-003`
- `F-013`
- `F-014`
- `F-005`
- `F-006`
- `D-001`
- `D-002`
- `D-003`
- `D-004`
- `F-007`
- `F-008`
- `F-009`
- `F-010`
- `F-011`
- `F-012`
- `D-005`
- `D-006`
- `D-007`
- `D-008`
- `D-009`
- `D-010`
- `D-011`
- `D-012`
- `D-013`
- `D-014`
- `D-015`
- `D-016`
- `D-017`
<!-- PPS:ACTIVE:END -->

## Authority Records

### M-001 [active]

- Summary: Use globally stable authority IDs and retrieve the active package by its explicit workset manifest.
- Source: PPS/1.1 bootstrap.
- Scope: Entire project.
- Supersedes: none.
- Affects: State, context recovery, decisions, review packages.

### M-002 [active]

- Summary: A package cannot close until its changed artifacts, authority records, current capsule, hot state, workset, and coverage agree and declared verification passes.
- Source: PPS/1.1 bootstrap.
- Scope: Every package close.
- Supersedes: none.
- Affects: Review, approval, handoff, finalization.

### M-003 [active]

- Summary: PPS is process-only for this repository. Do not import PPS product goals, skill source tree, or roadmap into WZ deliverables; reference only resume/authority/workset/close logic (and the external toolset path when scripts are needed).
- Source: User clarification 2026-08-07 — WZ task has no content overlap with PPS; only work logic is cited.
- Scope: Entire project, all packages.
- Supersedes: none.
- Affects: README, MAIN, skill authoring, dependency policy.

### F-001 [active]

- Summary: Product target is a general Agent Skill for WezTerm (wz) that strengthens AI-agent interaction and efficiency, centered on the AI STAR CUBE workbench model.
- Source: User project brief 2026-08-07 + morning WezTerm sessions.
- Scope: Product definition.
- Supersedes: none.
- Affects: Objective, skill description, MAIN.

### F-002 [active]

- Summary: Morning development produced a live AI STAR CUBE WezTerm config (not this git repo) under `%USERPROFILE%\.config\wezterm\` with workbench modules (keys, status, projects, desk, sidebar, help/cheatsheet, layouts, etc.).
- Source: Local filesystem + Grok sessions 2026-08-07.
- Scope: Implementation reference; skill may document paths but should not claim this tree is the product repository.
- Supersedes: none.
- Affects: MAIN recovered requirements, skill references.

### F-003 [active]

- Summary: Binding design principles — lowercase-first keys; avoid Ctrl+Shift letter chords as primary; F-keys for direct actions while avoiding F1/F2/F5/F10/F12; mouse-ok actions need not be bound; do not steal Grok F2 or Ctrl+;; WezTerm-focus-only bindings (not OS-global).
- Source: User feedback morning 2026-08-07 (IME, conflicts, adversarial key audit).
- Scope: Skill and any recommended key policy.
- Supersedes: none.
- Affects: keys policy sections in skill and MAIN.

### F-004 [superseded]

- Summary: Task model uses WS (workspace name) and DESK (task root path); F9 selects/enters task; F6 opens 3-pane AI desk on DESK; F7 opens Explorer on DESK; F8 toggles cheatsheet; Leader is **Alt+z** then lowercase (legacy Alt+; kept only for a few chords; primary docs must not teach Alt+; as Leader — CN IME often never enters LEADER).
- Source: `keys.lua` + live workbench 2026-08-09 (IME-safe Leader); morning iteration for F6–F9 model.
- Scope: Skill interaction contract.
- Supersedes: early morning experimental F2/F3 explorer/project bindings; teaching Leader as Alt+;.
- Affects: skill key tables, agent guidance, cheatsheet, MAIN key map.
- Superseded-by: **F-013 + D-007**（2026-08-13 用户正式退役 Leader；F8/F9 早已随 keys.lua 精简下线）。WS/DESK 任务模型部分由 F-013 继承。

### F-005 [active]

- Summary: Grok Build session top-bar workspace is the process cwd at session start; shell `cd` inside an agent does not change it. Correct approach is start/reopen with `--cwd` (or launch from target directory).
- Source: Observed in this session; confirmed with `grok --help` (`--cwd`).
- Scope: Onboarding and skill “open project” guidance.
- Supersedes: none.
- Affects: launch scripts, skill troubleshooting.

### F-006 [active]

- Summary: Left Explorer (F7) and the focused AI conversation must share the same task root. DESK for Explorer is resolved from focused Grok/Codex pane cwd (`--cwd`) and/or per-tab desk before falling back to window workspace map. Sidebar entries expose clickable file/folder links that open with the OS default application.
- Source: User workbench requirement 2026-08-07 (screenshot: WS:home/DESK:profile vs Grok top bar WZ_Skill).
- Scope: Live WezTerm workbench (`desk.lua`, `projects.open_sidebar`, `sidebar.ps1`, mouse hyperlinks).
- Supersedes: F7 only reading window-level `home` desk without AI pane sync.
- Affects: C-WB behavior, status HUD, open-project.ps1 desk-roots write, MAIN backlog.

### D-001 [active]

- Summary: Product / workflow family name is **WZ-AiWorkBench**. Final form may comprise multiple skills and/or other engineering modules; do not treat a single `wz-skill` package as the product ceiling.
- Source: User decision 2026-08-07.
- Scope: Naming, packaging roadmap, skill frontmatter later, docs titles.
- Supersedes: informal placeholder name `wz-skill` as product identity (path may remain temporary scaffold only).
- Affects: MAIN, PROJECT_STATE, skill naming when packaging starts, README.

### D-002 [active]

- Summary: **Workbench-first.** Current core focus is iterating the live AI STAR CUBE / WezTerm workbench until it fully meets personal requirements. Skill encapsulation and multi-skill packaging are deferred until the workbench is accepted as “done enough.” Do not prioritize authoring distributable `SKILL.md` over workbench UX/features.
- Source: User decision 2026-08-07.
- Scope: All packages until user re-opens packaging phase.
- Supersedes: PKG-001 emphasis on shipping reviewable skill body as immediate Next.
- Affects: Stage interpretation, package goals, Write/Verify targets, agent task selection.

### D-003 [active]

- Summary: **Project identity is frozen at bind/create.** 「项目名」= `desk-roots.tsv` left column (binding name). 「项目路径」= right column absolute path. Optional `<path>\.wz-project` reinforces both. Grok session title / generated_title / cwd leaf are **not** the project name. Weak/system paths (home, Desktop, Documents root, Downloads, AppData, Temp, Windows) and reserved names must never become task projects. Real work sessions launch only with `grok --cwd <strong project path>`.
- Source: User two-step correction 2026-08-09 (gates first, then create-flow path freeze).
- Scope: Live workbench (`desk.lua`, `bootstrap.ps1`, `projects.lua`, `launch.lua`, `open-project.ps1`) and any future skill open-project guidance.
- Supersedes: informal use of home/Desktop as desk-roots tasks; Project column = session cwd leaf.
- Affects: Init list, F9, status path slot, F6/F7, session scatter prevention.

### D-004 [active]

- Summary: **Multi-model handover 设计定案**（原 P-007，全文见 `docs/MAIN.md` §「Multi-model handover」）。任务身份与模型解耦：任务 = desk-roots 绑定，agent 会话只是运行时实例。同模型接手用各 CLI 自有 resume（kimi = `kimi --continue`，cwd 分组）；跨模型接手走文件态交接物（PPS 项目 = 恢复包；一般项目 = `<根>\.wz-handoff.md` 固定模板），transcript 显式排除。启动槽位泛化：`open-project.ps1 -Agent <grok|kimi|codex>`（默认 grok），`desk-roots.tsv` 可选第三列 `agent`（缺省 grok，向后兼容），Init 新建向导加选 agent 步，HUD 显示当前页签 agent；门禁 R1–R6 逐字保留。并发默认串行、无锁。实施按 MAIN §7 切片 1–4。
- Source: User approval 2026-08-09（「根据你推荐方案执行」）。
- Scope: Task model, launch flow, workbench UI, handover contract, future skill protocol.
- Supersedes: 单模型 Grok 默认假设（F-010 所指缺口）。
- Affects: MAIN §Multi-model handover, open-project.ps1, desk.lua/projects.lua/bootstrap.ps1（live）, live-workbench 快照, 验收清单。

### F-007 [active]

- Summary: Hard gates R1–R6 — (R1) force `--cwd` on project Grok launches; (R2) weak/system paths never project roots; (R3) project name from desk-roots / `.wz-project` only; (R4) project path frozen at create/bind; (R5) `set_root`/bind refuse weak + reserved; (R6) UI Project column uses name-for-path reverse lookup. home/Desktop demoted from TASK list (SYS only with `a` ShowAll); launch menu no longer offers “Grok @ home”.
- Source: Implemented 2026-08-09 in live WezTerm workbench.
- Scope: Session identity vs project content separation.
- Supersedes: none.
- Affects: bootstrap Init, desk.lua, projects F9, launch menu.

### F-008 [active]

- Summary: New-task wizard (`c` in Init) freezes name+path in one step: creates folder if needed, writes `desk-roots.tsv` and `<path>\.wz-project`, opens Grok only with `--cwd` equal to that path (via `wezterm cli spawn --cwd`). Default parent is portable (`WZ_PROJECTS_ROOT` → existing `*:\GrokProject` → `Documents\GrokProjects`). Manual full path allowed only if strong.
- Source: Implemented 2026-08-09; portability fix same day.
- Scope: Project create/bind flow.
- Supersedes: loose wizard that could bind home/Desktop; hard-coded `G:\GrokProject` only.
- Affects: Init wizard, open-project.ps1.

### F-009 [active]

- Summary: **Third-party install path.** Repo ships `Install-WZ.ps1` + `live-workbench/` so another Windows user can clone and obtain the same workbench shell (not the author's private projects/sessions). Installer backs up existing config, copies modules, creates empty desk-roots (or binds clone), runs doctor. Does not copy example.tsv as real bindings. Grok resolved via PATH + common paths.
- Source: Adversarial portability audit 2026-08-09.
- Scope: Onboarding, public GitHub distribution.
- Supersedes: manual-only INSTALL.md copy recipe as primary path.
- Affects: README, `docs/PORTABILITY.md`, Install-WZ.ps1.

### F-010 [active]

- Summary: **既有设计未预留「多个模型接手同一任务」。** 任务模型与工作台启动路径以 Grok 单一模型会话为默认假设，缺少跨模型（Grok / Kimi / Codex / …）对同一任务的可移植交接机制；会话历史不可跨模型携带，必须另有文件态交接物。本会话（Kimi 经 PPS 恢复包接手 Grok 推进的任务）即为该缺口的实证与可行模式的雏形。
- Source: User observation 2026-08-09.
- Scope: Task model, launch flow, handover contract.
- Supersedes: none.
- Affects: MAIN task model / backlog, future P-007 handover design, packaging-phase skill protocol.

### F-011 [active]

- Summary: **Kimi Code CLI 启动/续接手事实。** `kimi` 在**当前工作目录**开新会话，**没有 `--cwd` 启动参数**——要在指定项目路径启动须由外部设定进程 cwd（如 `wezterm cli spawn --cwd <path> -- kimi`）。`kimi --continue` 续当前目录最近一次会话；`kimi --session [id]` 恢复指定会话。会话按工作目录分组持久化于 `~/.kimi-code/sessions/<workDirKey>/`。`kimi export` / `/export-md` 可导出会话（归档/调试用，不作为跨模型交接物）。
- Source: Kimi Code 官方文档 2026-08-09 — `kimi-code-cli/reference/kimi-command.html`、`kimi-code-cli/guides/sessions.html`（kimi.com/code/docs）。
- Scope: Multi-model handover design (P-007), launch flow, agent registry.
- Supersedes: none.
- Affects: MAIN §Multi-model handover agent 注册表与启动槽位泛化。

### F-012 [active]

- Summary: **Codex CLI 启动/续接手事实（本机 v0.142.5 实测）。** `codex` 有 `-C/--cd <DIR>` 指定工作根（顶层与 `resume` 子命令均支持）；`codex resume --last` 续最近会话，`codex resume [SESSION_ID]` 续指定会话（picker 按当前 cwd 过滤，`--all` 取消）。会话存 `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`，首行 `session_meta` 含 `id`/`cwd`/`timestamp`/`model_provider`；`~/.codex/session_index.jsonl` 提供 `{id, thread_name, updated_at}` 索引。WinGet 安装解析到 `codex.cmd` 垫片，**不得直接作 CreateProcess argv0**（有 freeze 前科），须解析真实 exe 或经 PowerShell host 包装。
- Source: 本机实测 2026-08-09（`codex --help`、`codex resume --help`、`~/.codex/sessions/` 40 个 rollout 文件 + session_index.jsonl）。
- Scope: Multi-model handover, launch flow, session enumeration, Install-WZ/open-project exe 解析。
- Supersedes: MAIN 旧表述「codex = process cwd (no --cwd)、未硬化」。
- Affects: MAIN §Multi-model handover 注册表 codex 行、bootstrap.ps1 codex 支持、sidebar/open-project 路由。

### F-013 [active]

- Summary: 现行键位与入口事实（2026-08-13 用户确认）：**无 Leader 层**；全局键 = F1 速查 / F3 新建向导 / F4 关窗格 / F5 重载（Ctrl+Shift+R 应急）/ F6 三栏 AI 桌（按 desk-roots 第三列路由 agent）/ F7 Explorer 侧栏；F2 与字母键留给 agent CLI；F8–F12 刻意不绑；新页签/＋/冷启动 = Init 面板（同屏两步：LIST 选任务行 → AGENT 区选 agent）；纯 shell 逃生 = Init 按 `s`。任务模型 WS/DESK、R1–R6 门禁自 F-004 逐字继承。F1/F5 是 F-003「避开」原则的有意识例外（F1 可能被 Windows 帮助吞、面板内 q 兜底；F5 有 Ctrl+Shift+R 冗余）。
- Source: 用户 2026-08-13「正式退役leader」「我其实用不太到」+ live `keys.lua` 现状（`config.leader = nil`）。
- Scope: 键位契约、文档教学、验收清单。
- Supersedes: F-004（F9/F8/Leader Alt+z 模型；WS/DESK 部分由本记录继承）。
- Affects: MAIN 键位表与验收清单、cheatsheet、Install-WZ 文案、help.lua、keys.lua。

### F-014 [active]

- Summary: **DeepSeek CLI 启动/续接手事实（2026-08-14 本机实测接入）。** DeepSeek 官方无 CLI；采用社区版 `@kavienw/deepseek-cli`（npm 全局安装，本机 v0.5.0，shim 落点 `%APPDATA%\npm\deepseek.cmd`，已在用户 PATH）。**无 `--cwd`**——进程 cwd 即项目身份（kimi 同款）；同模型续接手 = `deepseek --continue`/`--resume`（按 `process.cwd()` 恢复已存会话）；会话存 `~/.deepseek-cli/sessions/<sha256(path.resolve(cwd)) hex 前 16 位>.json`（一项目一文件；文件名不可反解，工作台经「已知候选路径（desk-roots+favorites）哈希探测」识别绑定项目的 deepseek 会话——哈希算法 PS↔Node 对拍一致，含 CJK 路径与尾分隔符边界；非绑定路径不枚举）。REPL 进入时自动恢复该项目会话（CLI 自身行为），故 ForceNew 无法保证全新空白上下文。**需 DeepSeek API Key**（platform.deepseek.com）：首次交互启动在页签内提示录入并自动保存到 `~/.deepseek-cli/config.json`；`--api-key`/`DEEPSEEK_API_KEY` 亦可。npm `.cmd` 垫片与 codex 同族——spawn 一律经 PowerShell host wrap，绝不做 CreateProcess argv0。
- Source: 用户 2026-08-14「请为我直接安装deepseek CLI 并调通链路，并接入到我这个工作流中」+ 本机安装/拆包核验（`dist/session.js`/`index.js` 源码实证）。
- Scope: agent 注册表、启动/续聊/枚举/安装路径、文档。
- Supersedes: none.
- Affects: bootstrap.ps1（Find-AgentExe/peers/Start-DeepSeekTab/Invoke-AgentLaunch/Read-DeepSeekSessionSummaries/向导）、launch.lua、layouts.lua、status.lua、resume.lua、desk.lua、projects.lua、open-project.ps1、cheatsheet、MAIN §Multi-model。

### D-005 [active]

- Summary: **Agent 平权与缺省解析。** 工作台对 grok/kimi/codex 提供对等能力：会话枚举、启动、同模型续聊、HUD 识别、侧栏「在此开 AI」、安装 Doctor。缺省 agent 解析顺序统一为：**显式指定（desk-roots 第三列 / `open-project.ps1 -Agent` / 向导选择）> 本机已安装 agent 按 grok→kimi→codex 取第一个**。desk-roots 写出方一律显式写第三列（含 grok），读取方容忍两列旧行。任何单一 agent 缺失不得阻断其它 agent 的完整使用（含 Install-WZ Doctor：≥1 个已装即通过）。
- Source: 用户指示 2026-08-09「项目与 grok 解耦，所有 agent 平权启动」（对抗性审查后执行）。
- Scope: 全部启动/恢复/枚举/安装路径，live config + 仓内脚本 + 文档。
- Supersedes: D-004 中「缺省 grok」的隐式默认语义（向后兼容由解析顺序保证）。
- Affects: launch/layouts/resume/desk/projects lua、bootstrap.ps1、sidebar.ps1、profile-snippet.ps1、open-project.ps1、Install-WZ.ps1、wezterm_load_guard.ps1、README/cheatsheet/INSTALL。

### D-006 [active]

- Summary: 批准 P-008 兼容性/加固审查（`docs/compat-hardening-review.md`）并按其建议顺序施工：H-1/H-2/H-3 门禁闭环 → M-1/M-2 → M-5 验证先行 → L-1–L-7 批清。固化规则：一切 spawn 前先过 R1 强路径门禁与已解析 agent 的 CLI 存在性门禁（缺一不 spawn）；desk-roots 四个写出方（desk.lua / sidebar.ps1 / bootstrap.ps1 / open-project.ps1·Install-WZ.ps1）一律显式写第三列（含 grok）；desk-roots 写盘一律 temp+move 原子化；sidebar 写绑定与 desk.lua set_root 同一套 R5 弱路径+保留名表（PS 表与 lua 表保持对齐）。M-3（open-project 可移植性）留待后续包；M-5 经实测判定无需修。
- Source: 用户 2026-08-13「根据建议执行」批准 P-008 建议施工顺序。
- Scope: live workbench 全模块 + 仓内 Install-WZ/open-project/scripts 验证器 + live-workbench 镜像。
- Supersedes: none.
- Affects: launch/layouts/resume/projects/desk/help lua、sidebar.ps1、bootstrap.ps1、Install-WZ.ps1、ENVIRONMENT.md、validate_project.ps1、prototypes/hardening-smoke/。

### D-007 [active]

- Summary: **Leader 前缀键正式退役**——不作为功能、不在任何文档教学；`keys.lua` 保持 `config.leader = nil`。Leader 仅保留为「扩展槽」规则：新动作默认先进 Init 面板本地键；须同时满足「全局上下文（不依赖面板在场）+ 每日高频 + 鼠标不便」三条才配占全局键；全局 F 键耗尽时才可重议 Leader，且重议需要新的 D。
- Source: 用户 2026-08-13「正式退役leader」（前一轮分析结论：当前 6 个全局动作单键容量足够，无 chord 刚需场景）。
- Scope: 键位契约、全部键位相关文档与教学文案、后续功能入口设计。
- Supersedes: none（F-004 的 Leader 事实部分由 F-013 取代）。
- Affects: keys.lua、docs/MAIN.md 键位表与验收清单、cheatsheet.txt、Install-WZ.ps1、help.lua、后续封装阶段 skill 键位章节。

### D-008 [active]

- Summary: **Agent 平权启动与多步交互同构。** (1) 一切任务启动入口必须给出「全量已装 agent 的平权选择」——默认项 = D-005 缺省解析（desk-roots 第三列路由），取消（q/Esc）= 零 spawn；仅 1 个已装 agent 时选择器自动跳过；0 个时 toast 不 spawn。F6 三栏桌经 `act.InputSelector` 实现（默认项排第一带 ▶ 标记，fuzzy=off，↑↓+Enter）；Init 面板第 2 步经常驻 AGENT 区实现。(2) 多步交互同构规则：同一流程的每一步共享同一套键——j/k/↑↓ 移动光标 + Enter 确认光标项，或数字键入共享缓冲 + Enter 确认数字项；Backspace 退格缓冲；q/Esc 逐级返回。数字键不再即时触发（单键直选废除），一切跳转经 Enter 确认。
- Source: 用户 2026-08-13「开展一次任务时，用户有充分的 AGENT 切换选择，同时每个 AGENT 都是平权的选项」+「两步的交互体验是相似的，比如两步都可以光标选择+enter，也都可以选择数字+enter」。
- Scope: 全部任务启动入口（Init 两步流、F6、后续一切新入口）与多步交互设计。
- Supersedes: Init 第 2 步「数字单键直选、无光标」语义（2026-08-13 同屏 AGENT 区版）。
- Affects: bootstrap.ps1（AgentCursor/NumBuf 状态、armed 模态循环）、layouts.lua（pick_agent/spawn_workbench_fresh）、MAIN B1/B4、cheatsheet、后续一切启动入口设计。

### D-009 [active]

- Summary: **Init 静态屏 + 行输入（废除逐键重绘）。** 两次逐键重绘渲染器（清屏重绘 / 无清屏覆写）在 WezTerm ConPTY 宿主下实测均闪烁，用户裁决「init 页的稳定、清晰、性能最重要，宁可只要数字输入」。定案：Init 屏幕**静态**——只在状态转换（待命/启动/取消/刷新/提示）时整屏重绘一次（`ScreenDirty`/`RowsDirty` 双闸），导航输入用 `Read-Host` 行模式，键入过程零重绘。两步同构文法保留：第 1 步 `wz> <num>`（`n<num>`=强制新会话），第 2 步 `agent> <num>`；均为「数字+Enter = 选 / Enter 空 = 默认 / q = 返回」。面板内光标（AgentCursor/NumBuf/ReadKey 循环/行选中高亮）全部移除；顺带获得重定向宿主可运行（管道可冒烟）。
- Source: 用户 2026-08-13「闪烁甚至更厉害了」「跟上个版本没区别」+ 早前「如果光标影响很大，我宁愿只有数字输入的方式进行，init 页的稳定，清晰，性能好是最重要的」。
- Scope: Init 面板交互与渲染；后续一切面板类 UI 默认静态屏 + 行输入，逐键重绘需新的 D 才可复活。
- Supersedes: D-008 的交互**实现**部分（光标移动 + 数字缓冲 + Enter 同构的逐键方案）。D-008 的 **agent 平权选择原则不受影响**（全量已装 agent、默认=D-005 路由、取消零 spawn），由 F6 InputSelector 与 Init 行输入共同承载。
- Affects: bootstrap.ps1（Show-Screen/主循环/AGENT 区/COMMAND 区）、MAIN 键位表与清单 B4、cheatsheet、后续 UI 设计。

### D-010 [active]

- Summary: **组合输入加速道（P-010 批准）。** 两步高亮行输入为主干不变；默认视图**封顶 9 行**（任务号恒为个位数），视图内两位数输入 = `<任务号><agent号>` 一次直启（如 `13` = 任务 1 + agent 3，`n13` = 强制新会话变体）；R1 门禁照常先过（Invoke-RowPrimary/NewSession 不过则不启动）。`a` 全量视图（≤18 行）组合自动失效、纯数字回退为行号，歧义归零。单个数字仍走两步慢道（可看清默认 agent 再确认）。
- Source: 用户 2026-08-13「根据你的推荐方案执行」（对 2a vs 2b 分析的裁决：2a 主干 + 2b 叠加）。
- Scope: Init 输入文法、默认视图行数策略。
- Supersedes: none.
- Affects: bootstrap.ps1（Build-Rows 9 行封顶、主循环组合解析、COMMAND 提示）、MAIN §5 与清单 B4、cheatsheet。

### D-011 [active]

- Summary: **页签标题只许落在「验证过的 pane-id」上，且 Init 页签在显示层永久钉住为 "Init"。** 一切 `wez cli spawn` 之后的改名必须经 `Set-SpawnedTabTitle`：(1) spawn 的 ExitCode ≠ 0 → 不改名；(2) spawn 输出必须 stderr 隔离（`2>$null`）且**整段输出严格等于 pane id**（`^\d+$` 全匹配，多余内容一律拒改）；(3) 永远使用 `set-tab-title --pane-id <id>` 的显式形式——无 id 形式作用于 CLI 的当前页签，会把 Init 页签污染成新启动任务的标题（2026-08-13 晚用户实测：Init 与 "WZ_Skill | Kimi" 两个同名页签并排）；(4) 自指 guard：解析出的 paneId 等于本 pane（$env:WEZTERM_PANE）时拒改；(5) 每次调用留痕 `workbench/tabtitle-debug.log`（exit/self/pane/action/title/raw 输出）。**显示层钉住**：bootstrap.ps1 启动时对自身 pane 打 WezTerm user var `wz_init=1`（OSC 1337 SetUserVar，同 cheatsheet.ps1 的 star_cube_help 机制；重定向宿主下跳过）；status.lua `tab_project` 第一行检测该 var → 恒返回 "Init"，tab_title 被写什么都无法改变显示；同时 4 个启动点在每次 spawn 后用 `Assert-InitTabTitle` 把本页签标题回钉为 "Init"。
- Source: 用户 2026-08-13 23:32「init 栏一旦启动了某个项目，页签名就会直接被污染」+ 2026-08-14 09:58「还是污染掉了，我希望 init 页的页签名，永远显示 init」+ 修复中确立的实现不变量。
- Scope: bootstrap.ps1 全部 spawn 路径（Grok/Kimi/Codex/新建向导）、status.lua 页签渲染、后续任何新增 spawn 点。
- Supersedes: none（旧代码的 fallback 无 id 改名路径与非严格 `(\d+)` 首数字抓取被废除）。
- Affects: bootstrap.ps1（Set-SpawnedTabTitle 严格化/日志、4 个 Start-*Tab 调用点）、后续新增 agent 启动函数。
- Note: 显示层钉住的 user-var 实现（OSC emit + Assert-InitTabTitle 回钉）于 2026-08-14 被 **D-012** 的 argv 检测取代并已撤除；本条写入侧不变量（严格 `^\d+$`、自指 guard、调试日志）保持 active。

### D-012 [active]

- Summary: **Init 页签 = 短命启动器：任务启动成功即关闭原 Init 页签；存活期间显示层按 argv 钉住恒显 "Init"。** (1) 启动闭环：`Complete-AgentPick` 是一切启动的唯一漏斗（两步慢道 / 组合直启 / 强制新会话）；`Start-*Tab` 仅在真实 spawn 成功时返回 `$true` → `Close-CurrentWezPane` 杀掉自身 pane（kill 成功则不返回；无 wez CLI/pane id 返回 `$false` 且**不 exit**，降级为正常重绘）。取消（q/Esc）、门禁拒绝、spawn 失败一律不关闭。(2) 显示钉住：status.lua `tab_project` 第一行 `tab_has_init_pane`——按 pane 前台进程 argv 含 `bootstrap.ps1`/`wz-init` 判定（desk.lua 门禁同族机制，本机已在用；format-tab-title 的 PaneInformation 快照无进程方法，经 `wezterm.mux.get_pane` 解析真 pane；pane_id + TTL 4s 缓存控重绘成本），命中即恒返回 "Init"——覆盖一切出生路径（gui-startup / F3 / Ctrl+T / 「+」）与任何 tab_title 状态，新 Init 页出生即正名，不再出现 "Shell"。(3) 昨日 user-var 方案（OSC 1337 emit + Assert-InitTabTitle）废除：PaneInformation.user_vars 在本机未验证，且 wezterm 自动重载只盯主配置文件、不盯 `workbench/*.lua` 模块——钉住代码从未被加载，这是「完全不行」的机制层原因。
- Source: 用户 2026-08-14 10:36「完全不行…不能做的话直接放弃不要浪费时间」+「在选择了项目启动成功后，把原始的init页直接关闭，这也是一种干净的解决思路」。
- Scope: Init 生命周期（启动成功即关）、页签显示层（Init 恒显）。
- Supersedes: D-011 的显示层钉住实现（user var + 回钉）；D-011 写入侧不变量不受影响。
- Affects: bootstrap.ps1（Complete-AgentPick/Invoke-AgentLaunch 返回值链、Start-*Tab 成功返回 $true、Close-CurrentWezPane 降级语义）、status.lua（pane_is_init/tab_has_init_pane + TTL 缓存）、cheatsheet.txt（Init 流程补「启动成功后自动关闭」）。

### D-013 [active]

- Summary: **颜色标准：亮黄（Yellow）= 全局唯一「可输入」可供性色，且被预留。** 允许用亮黄的只有两类：(1) **选项索引芯片**——Init LIST/AGENT 序号 `[n]`、COMMAND/侧栏/帮助屏键位芯片（`Write-UiChoice` 函数内硬编码芯片恒亮黄、标签恒 Gray，`-Fg` 仅对无芯片行生效，新增选择行不可能错色）；(2) **行输入提示符前缀**——`wz>` / `agent 1-N (…)` / `explorer>` / wizard `Read-LinePrompt` / COMMAND 区 ` >_` 标记（用户 2026-08-14 14:15 批准侧边栏 `explorer>` 亮黄前缀模式，定为全局通用设计，强化输入认知）。**禁黄**：一切框框（盒边框+盒标题）、表头、状态行、装饰——COMMAND 区边框已归 DarkGray（中性框让区内黄芯片成为唯一输入信号），盒原语默认边框全部 DarkGray（漏传 -Border 不会误用预留色）。Init 两步流保留 8-13 批准的阶段高亮：激活步骤芯片亮黄、非激活暗灰，叠加 `<< step N` 标记。语义分层：信息提示 = Cyan/White/Gray 系；成功/默认标记 = Green；错误/门禁 = Red（既有 17 处不动）；次级注意 = DarkCyan（原 DarkYellow 黄色系用法全部清零）；猫猫装饰/AGENT 区边框 = Magenta；结构边框 = DarkGray/Cyan/Magenta 按区。wezterm 页签条的品牌徽章（★ AI STAR CUBE 金底，status.lua）属徽章式标识、不在终端内容区，不在本标准约束内。
- Source: 用户 2026-08-14 13:40「我希望所有输入选项的颜色，都是唯一的，是最显眼的颜色…敲定下来这个选项后，其他地方的所有终端亮色构建，都不要使用这个颜色，以免污染标准」+ 2026-08-14 14:15「包括init页的这些框框和表头也不要用亮黄」「侧边栏输入框的前缀也有同样的亮黄色是很好的设计…定为全局通用设计」。
- Source: 用户 2026-08-14 13:40「我希望所有输入选项的颜色，都是唯一的，是最显眼的颜色，这个逻辑贯彻工作流的唯一…敲定下来这个选项后，其他地方的所有终端亮色构建，都不要使用这个颜色，以免污染标准」。
- Scope: live workbench 全部 PowerShell 界面（bootstrap.ps1 Init/wizard/splash/COMMAND、sidebar.ps1 explorer）与后续一切终端 UI；封装阶段 skill 的终端配色章节。
- Supersedes: COMMAND 区边框/字段行整行亮黄、sidebar KEYS 框亮黄边框等框体用色实践（框框禁黄后全部归 DarkGray）。
- Affects: bootstrap.ps1（Write-UiChoice/Write-BoxKeyRow/splash/loading/wizard/COMMAND/提示符）、sidebar.ps1、后续一切新 UI。

### D-014 [active]

- Summary: **鼠标链接语义：普通单击打开超链接，拖拽选择不受影响；可执行（launcher）扩展永不生成超链接。** (1) options.lua 鼠标绑定：左键 Up(NONE) 从 `CompleteSelection`（只完成选区、拒开链接，08-09 误开 .cmd/信任目录事故的硬化产物）改为 `CompleteSelectionOrOpenLinkAtMouseCursor("Clipboard")`——有选区则完成选区，无选区且指针落在链接上则打开；Ctrl+Click / Middle-Click 保留为别名。(2) 结构性防误开：sidebar.ps1 `Write-ClickablePath` 对 launcher 扩展集（.exe/.cmd/.bat/.com/.scr/.reg/.vbs/.vbe/.lnk/.msi）不生成 OSC-8（渲染为纯文本，外观不变），此类对象只能经键盘 `o N` / 裸 `N` 显式打开；hyperlinks.lua 的路径模式规则本就只匹配安全扩展白名单（.md/.ts/.py/...），全局无双击执行面。(3) 全链路审计：OSC-8 唯一发射口为 sidebar `Write-ClickablePath`（文件行/VIEW 头/DESK 头三个调用点），护栏一处生效全覆盖。
- Source: 用户 2026-08-14 16:06「侧边文件夹的对象又不可以点击了，修复，审查，加固，推送远端」。
- Scope: live workbench options.lua 鼠标绑定、sidebar.ps1 链接发射；后续一切终端可点击内容。
- Supersedes: 08-09 起的「普通单击拒开链接」硬化（`CompleteSelection`）。
- Affects: options.lua（mouse_bindings）、sidebar.ps1（Write-ClickablePath launcher 护栏）、prototypes/hardening-smoke/test-sidebar-link.ps1（回归用例）。

### D-015 [active]

- Summary: **新建项目向导收敛为四步并移除历史 `[9]` 别名。** 流程固定为「名称 → 位置 → Agent / CLI → 确认」；选择身份与其启动 CLI 是一个不可拆分的选择，所选 ID 同时写入 `desk-roots.tsv` 第三列并用于首次启动，禁止出现「Codex CLI + grok agent」等矛盾组合。`PowerShell only` 是非 AI 逃生项，显式写 `shell` route id，不得由写出器暗补成 grok。位置页手输父目录入口仅保留 `[0]`，`[9]` 不再显示、解析或出现在错误提示/教学中。
- Source: 用户 2026-08-15 明确修正：「CLI 和 agent 没有分离的必要，合并成一个选项」「0 或 9 是历史设计错误，只保留 0」。
- Scope: F3 / Init `c` 新建向导、终端文案、验收清单与教学。
- Supersedes: D-004 中「新建向导另加选 agent 步」这一交互切片；历史 `[9]` 父目录别名。
- Affects: live `bootstrap.ps1`、cheatsheet、live README、MAIN §Multi-model handover / R-UI-3 / A3。

### D-016 [active]

- Summary: **Agent 候选采用开放式、元数据驱动探测，COMMAND 固定单元格对齐，删除 Grok 专属 Dashboard。** (1) Init/F3/F6/Installer/Sidebar/open-project 共用 `agent-discovery.ps1`，每次 Init 冷启动重新扫描，任务步与 Agent 选择步均可按 `r` 清内存清单后原进程重扫。探测合并当前进程 PATH 与最新用户/系统持久化 PATH；发现源为 npm/Python 包元数据、可执行文件版本元数据、`*.wz-agent.json`，以及用户级专属 `app\bin` 独立 EXE 内的通用 AI/coding-agent 静态能力声明（有扫描上限、文件指纹缓存和同负载别名折叠）。不得用产品名或固定类型表决定候选资格，也不得执行候选命令做探测。仍无任何自描述证据的独立二进制可由 `agent-registry.local.tsv` 任意登记，安装器永久保留；仓库自带 TSV 不含产品行。未知新 Agent 必须等权展示并可在项目 cwd 新开，产品专属 resume 逻辑只能作为可选适配器，不能成为发现白名单或未知项回退。(2) Init COMMAND 三行共享同一组三列宽度，后续入口的终端起始列固定，不随前项文案长度漂移。(3) 删除面板 `[d] dash(grok)`、处理分支、launch menu 的 Grok Agent Dashboard 与死代码；启动菜单无产品专属项。
- Source: 用户 2026-08-15 截图反馈「部分选项排列位置不整齐」「似乎还保留了 grok 的专属启动项，不符合平权」+ 后续明确要求「开放性探测，所有本地正确安装的 ai agent 都能正确展示，不写死任何类型」。
- Scope: Agent 安装发现、Init/F3/F6/Sidebar/open-project 候选与启动、COMMAND 网格、launch menu、安装器和文档。
- Supersedes: D-005 的固定首装顺序与「写出方缺省暗补 grok」切片；P-011/M2-6 中保留 Grok Dashboard 的例外；任何固定四类 Agent 候选表。D-004/F-011/F-012/F-014 的产品专属续聊事实仍只作为可选适配器有效。
- Affects: `agent-discovery.ps1`、`agent-registry*.tsv`、`bootstrap.ps1`、`launch.lua`、`layouts.lua`、`desk.lua`、`sidebar.ps1`、`Install-WZ.ps1`、`open-project.ps1`、MAIN/README/INSTALL。

### D-017 [active]

- Summary: **Windows-only 发布蒸馏。** 按「轻量、稳定、高性能、全面 Agent 兼容平权」四原则，对当前工作流做对抗性审查、基线量化、修复与重复回归；开放探测不得退化为产品白名单，专属能力只允许作为可选适配器。可计数的文件/会话读取必须共用真实总进度并在结果发布后才到 100%；不可计数的外部 Agent 就绪阶段使用不定进度动画，不伪造完成率。收口后将 GitHub 仓库改名为 `WZ_AiStarCube_win`，README/安装器明确只支持 Windows，并把验证通过的完整写集提交到远端。
- Source: 用户 2026-08-15 明确要求全面加固与性能蒸馏、循环迭代至当前需求最优、推送远端并增加 `_win` 后缀；随后要求执行上轮未完成任务，并补充猫猫读条与真实文件读取进度不同轴的问题。
- Scope: Agent discovery/launch/runtime、路径与写盘门禁、安装/Doctor、性能与对抗回归、Windows-only 文档和 GitHub 发布。
- Supersedes: 验收前不得发布的旧等待状态；不改变 D-002 的 workbench-first 产品路线。
- Affects: `live-workbench/`、`Install-WZ.ps1`、`open-project.ps1`、验证脚本、README/INSTALL/MAIN/状态文件、GitHub 仓库名与描述。

## Status Events

- 2026-08-19: **逃生舱对抗加固。** wrap 去掉 WZ_Skill 特判；F8 路径改用 `config_dir` 而非写死 `~\.config`；舱内 `q` 取消而不误启第 1 家；JOURNAL 无 BOM 追加；标题清洗 `|`/换行；repair 创建失败时仍能开壳；wz.ps1 Ensure 加 try。页签仍禁止用第三列冒充现场 Agent。
- 2026-08-19: **逃生舱补日记 + 报错提示 F8。** 每次 F8 向 `repair\JOURNAL.md` 追加时间/Agent/加载残片（超 80KB 截尾）。模块加载失败 toast、Init 零 Agent、F6 门禁、安装器 Doctor 失败、Init 崩溃包装均提示 F8。F8 的 spawn cwd 改为 workbench（不依赖 repair 目录已存在）。
- 2026-08-19: **F8 / wz 接到安装根 `repair\`。** cwd = `~\.config\wezterm\repair`（产品设施，不进 desk-roots）。页签 `WZ_Repair | 所选 Agent`。`status.lua` 删除「Shell/App → 第三列 Agent」。`wz.cmd doctor|report|repair` 与 F8/Escape-WZ 共用 escape-pod。安装器只补 INSTALL.txt 与缺失的 INCIDENT.md，不覆盖已有事故笔记。
- 2026-08-19: **F8 逃生舱改为 Agent 平权，并升为最高门禁 R0。** 舱体改走开放探测等权列表（一家直开、多家选号、零 Agent 留壳）；禁止写死 grok.exe。`AGENTS.md` R0 + `test-agent-parity.ps1` 纳入 `validate_project.ps1`：任何功能不得把某一家写成唯一入口。专属 `--cwd`/`-C` 仅作适配器。
- 2026-08-19: **PPS/1.1 实战应用复盘报告落盘并按用户反馈重写为 v2 问题驱动版（`docs/pps-application-review.md`）。** 用途：PPS_SKILL 蒸馏开发输入。v1 从机制清单宏观判定，用户指出两处不客观：① Assets/Sources 恒 none 是本项目无素材场景所致，不代表机制设计无意义；② 应从实际出问题的环节切入，而非宏观假设。v2 重写要点：判定口径改三档（A 实战验证有效 / B 本项目未触发不判优劣 / C 触发后暴露问题，无证据不进档）；核心改为十个问题复盘案例（C-1 接力覆盖 I5、C-2 BOM I1、C-3 splat 归零 I4/I4b、C-4 部署未生效 I3、C-5 方案返工 I2、C-6 覆盖表恒绿、C-7 CONTEXT 行限顶爆、C-8 P-006 挂起 6 天、C-9 工程红线无协议位、C-10 事件流膨胀），每案例含经过/机制表现/蒸馏启示；Assets/Sources、L1-L3、Stage、Package 全部归 B 档保留。蒸馏优先级：P0 = 接力交接条款（C-1）+ Verify 可执行化（C-2/C-3）+ Status Event 一等公民化（C-10）；P1 = 行为断言入协议 + 覆盖表改革/CONTEXT 瘦身 + P 老化；P2 = 命令词改意图映射；P3 = RED-LINES 标准模块（C-9）。边界：B 档机制不得因本报告删除；接力 ≠ 并发。未推送，待用户指示。

- 2026-08-19: **推送完成（d606ae7 → WZ_AiStarCube_win/main，纯快进）+ 功能提升分析报告落盘。** 推送前精确 diff 终审：15 改 14 新（Grok 三轮性能修改 + 归零事故双层修复 + 红线七条 + e2e 套件 + 补回的 Install-WZ 加固 + 事故报告），无杂项混入；推送后 `git status` 干净无分叉。演进报告 `docs/workbench-evolution-report.md`：五阶段编年（骨架门禁→平权统一→生命周期与色彩→开放化蒸馏→性能稳定）、起点 vs 现状十三维对照、五次关键转折的因果链、剩余风险清单。

- 2026-08-19: **AGENT 归零事故第二层修复 + 刚性防护落地 + 冲突评估完成。** (1) **第二层 bug**：splat 修好后冷启动仍零——新日志抓到 `List[object]` 经管道在 bootstrap 热 DLR 会话触发 PS 5.1 绑定器 bug（PSEnumerableBinder.MaybeDebase → ArgumentException），`Read-WzInventoryCache` 弃用泛型列表改普通数组即愈。前序 bug 掩盖后序 bug 的典型案例：splat 的 UserPathOverride 恰好绕过缓存读取路径。(2) **刚性防护**：新增 `test-init-e2e.ps1` 用户视角行为断言（AGENT 行数==探测数、三区标题、无红错误、r 刷新不变；含多帧取末帧、Start-Process 原生重定向两个测试基建教训）；`AGENTS.md` 新增**施工红线七条**（BOM 强制/三件套门禁/调用约定连带测/禁 splat/禁无日志空 catch/live 快照+对拍/多帧断言）；Install-WZ 被 Grok 会话覆盖丢失的 known-folder 加固**已补回**（I5 流程事故实证：未提交工作区在 Agent 接力间无保护）。(3) **冲突评估结论**：远端静止在 1d6e252（08-17 拉取后未动），全部未提交改动都位于最新远端提交之上，推送 = 纯快进，零冲突可能。(4) 报告：`docs/agent-incident-review.md`（四起事故编年史 + 工作流十大坑点 + Grok/Kimi Harness 实测短板 + PPS 六项缺陷评估）。回归：六套测试全绿、BOM/parse 0、镜像 16 对 SHA 一致、ls-fonts exit=0、load guard OK、validate + readiness OK。**待用户**：live 终验 + 批准推送（含 Grok 三轮性能修改、本次两层修复、红线与 e2e、补回的 Install-WZ 加固）。

- 2026-08-19: **AGENT 区归零事故修复（Grok 性能轮引入的回归）。** 用户报告 Init 的 2 AGENT 区只剩 Deepseek/全空。根因（探针二分实证）：Grok 为给探测调用加条件 `-Refresh`，把 `Get-AgentDefinitions` 里原本的**内联命名参数**改成数组 splat `@('-WorkbenchDir', $PSScriptRoot)`——PS 5.1 对该脚本做了**纯位置绑定**：`WorkbenchDir` 拿到字面量 `"-WorkbenchDir"`、真实路径落进 `UserPathOverride` → PATH 被替换成 workbench 目录本身 → npm/PATH/注册表三类发现源全灭 → 零 agent；静默是因为调用点 `try{}catch{}` 全吞且 UI 优雅降级为「no agent detected」空态（用户截图里的 1 家为缓存中间态噪声）。修复双轨：(1) bootstrap 改回内联双分支（`-Refresh` 条件直写），并在 catch 里落 `discovery-debug.log`——此调用点永久禁止 splat，注释留档；(2) `agent-discovery.ps1` 加 `[CmdletBinding(PositionalBinding=$false)]` 硬护栏——位置误绑从此**大声报错**（实测 `PositionalParameterNotFound`）而非静默归零。Grok 性能轮的其余成果（原子缓存 Replace、8MB/400ms 扫描封顶、路径形态接纳、20s 清单缓存、猫动画零 Sleep）全部保留。回归：Init 冒烟五家等权入列、`r` 强制重扫分支正常、open-discovery/loading-progress/sidebar-link/splash-wrap 四套全绿、launch.lua 配平 OK、ls-fonts exit=0、load guard OK、live↔镜像 16 对 SHA 一致。**教训（流程级）**：跨脚本调用只许内联命名参数；silent catch + 优雅降级 = 故障隐身斗篷，关键调用点必须留日志。

- 2026-08-19: **猫动画定位审查。** 设计是掩盖读取/启动的僵硬空屏，不是自己再卡一截。Init `Show-LoadingScreen` 先画后干活、读条跟进度走，符合定位（探测阶段原先停在 warming up，已改为发现中更新标签）。会话猫曾两极：5 帧 Sleep 375ms 是效率税；上轮为省税拿掉原生 `.exe` 封面，结果 Kimi/Codex/Agy 2–5s 黑屏无人盖，偏离定位。现统一为「1 帧立刻画 + 零 Sleep + 不 Clear + 马上 exec」，猫盖住 CLI 加载直到 TUI 接管；DeepSeek 行式 REPL 在 invoke 前 Clear，避免残帧。F6 `command_args` 同步同一封面。Splash 单测禁止 `Start-Sleep`，原生 EXE 也必须走封面包装。
- 2026-08-19: **全量启动性能盘查并修工作台可控段。** 本机分段实测：WezTerm 配载 `ls-fonts` 957ms；Init 面板 2.4s（探测子脚本 0.5s + 宿主 PS/绘制）；正式会话框慢在两层——(1) Init 给每个原生 CLI 再套 `powershell` + 5 帧猫 375ms + spawn 后 Sleep 200ms；(2) 外部 CLI 冷启动：kimi `--version` 5158ms、codex 3107ms、agy 2730ms、deepseek 2692ms，grok `--version` 仅 61ms。F6 本来就是直 spawn `.exe`，比 Init 开聊更快。F7 顶层列表 1ms。工作台已改：原生 `.exe/.com` 与 F6 一样直接 spawn；shim 只留 1 帧静态猫且 `-NoProfile`、零 Sleep；Init/F3/默认页签加 `-NoProfile`；探测结果 20s 文件缓存（`r`/`-Refresh` 仍全量）；Grok 列表不再读 `prompt_history`；Codex `--version` 按 exe mtime 落盘。本机 Init `q` 2.4s→1.4s。外部 TUI 就绪时间无法由工作台抹掉。
- 2026-08-19: **Init 本机打开极慢（仅此设备）。** 会话扫描正常（grok summary 18ms / codex 8ms）。耗时在开放探测：本机 `~\.grok\bin\grok.exe` 与 `agent.exe` 各约 136MB，能力词在约 119MB 处，整文件 ASCII 扫描单次约 20.5s。指纹缓存本应避免重扫，但 `Save-WzBinaryCache` 对已存在文件调用 `File.Replace(..., $null)` 抛错后被空 catch 吞掉，缓存停在 08-17 的旧 size；Grok 自更新后每次冷启动都 miss。此机还有同形态的 kimi/agy（140MB+），其他设备若只有 npm/小 CLI 则无感。修复：缓存改原子 Replace（真实 backup 路径）+ ticks 存字符串；单文件扫描封顶 8MB/400ms；超过上限且目录名匹配的用户级 `app\bin` 主命令按路径形态接纳，不再整文件读。本机探测 21594ms→537ms/188ms，Init `q` 约 2.4s；五家 Agent 仍在。回归：`test-open-agent-discovery.ps1` 全绿（含缓存真替换、ticks 字符串、9MB 专属 CLI <8s）；validate + readiness -Verified OK；live↔仓库 `agent-discovery.ps1` SHA 一致。
- 2026-08-16: **D-016 持久化 PATH 漏探修复与开放式独立 CLI 加固。** 用户现场在安装三套独立 Agent CLI 后重进 Init 仍只见 Codex。根因双层：(1) 安装器已把 `~\.kimi-code\bin`、`%LOCALAPPDATA%\agy\bin`、`~\.grok\bin` 写入用户 PATH，但长寿命 WezTerm/Codex 进程环境仍是旧快照，旧探测器只读 `$env:PATH`，故 Init 冷启动/`r` 都无法看到；(2) 三个 EXE 没有可用的 Agent 包清单/Windows 版本资源（其中一个只暴露通用 Node.js 资源），即便目录可见也会被静态元数据门槛漏掉。修复后探测器每次合并进程、User、Machine PATH，并冻结解析后的准确入口；对用户级专属 `app\bin` 中仍无清单的主 EXE，只做受限静态能力声明扫描，绝不启动候选，按路径+大小+mtime 缓存判定，相同负载别名折叠到与应用目录最匹配的命令。Init 的 `r` 现同时可用于任务步与已进入的 Agent 选择步。真实机冷扫描 1.614s、热缓存 0.165s，开放结果为 `Agy/Codex/Grok/Kimi` 四项；新回归用代码从未出现的 `nebula-code\bin\nebula.exe` 假 PE 验证旧进程 PATH、无清单/无版本资源、别名折叠、零执行与零 Agent 边界全绿。
- 2026-08-16: **Codex 续聊版本倒挂修复（D-017 增量加固）。** 用户现场错误 `rollout ... does not start with session metadata (code -32603)` 经只读核验并非文件头损坏：目标 rollout 905,754 bytes / 197 行，首行合法 `session_meta`、无 BOM，写入版本为 VS Code Codex `0.145.0-alpha.18`；工作台实际启动的 npm CLI 仅 `0.137.0`，旧 thread-store 无法反序列化较新会话格式。按 OpenAI Docs 的 CLI 更新/`codex resume <SESSION_ID>` 路径，将全局 `@openai/codex` 升至 npm latest `0.147.0`，同一会话 ID `019f7de1-4fbe-73d1-95ef-cf45f2d7e0c5` 已真实进入 TUI、显示历史并正常退出，原 `-32603` 消失。防复发：Codex 会话行携带 `session_meta.payload.cli_version`，用户明确选择 resume 后才执行一次并缓存 `codex --version`；已知运行时低于写入版本则保持 Init 页、提示升级与 `r` 重试，零 spawn；未知版本不误拦，开放 Agent 发现仍然不执行候选。新增 `test-codex-resume-compat.ps1` 覆盖旧版阻断、新版放行、未知值降级、版本字段跨 bound/recent 传播与本机版本实测。
- 2026-08-16: **D-017 收口并发布。** 完成面向「轻量、稳定、高性能、全面 Agent 兼容平权」的对抗性审查与循环回归：开放探测保持零产品白名单，任意自描述本地 Agent 可在 Init 冷启动或 `r` 刷新后等权出现；CLI/Agent 合并为四步向导单一选择，位置输入仅保留 `[0]`；COMMAND 网格对齐，移除 Grok 专属入口；启动前路径/可执行文件复验、原子写盘与安装哈希校验落地。猫猫加载动画改为会话源预枚举后的单一真实总量，结果发布前不显示 100%；外部 Agent 交接改用不定进度，不再伪造百分比。回归结果：29 个 PowerShell 文件解析零错误，开放探测/加载进度/启动包装/desk-roots 门禁/侧栏链接用例全绿，项目验证、readiness、WezTerm load guard 和真实 `ls-fonts` 全绿；重复安装与 20 对源文件/已安装文件 SHA-256 一致性通过。性能中位数：探测约 1.052s，Init `q` 约 1.663s，无常驻缓存或后台守护。完整变更提交 `f843453` 已推送至 `main`，GitHub 仓库已改名为 `WZ_AiStarCube_win`；本机安装备份为 `%USERPROFILE%\.config\wezterm.bak-20260815-090314`。后续只等待真实交互验收与基于观测的增量修正。
- 2026-08-15: **D-016 开放 Agent 探测 + COMMAND 对齐 + 专属入口清理完成并装载本机。** 新增 `agent-discovery.ps1`：不含任何产品名白名单、不执行候选程序，从 PATH 可见 npm/Python 元数据、exe VersionInfo、`*.wz-agent.json` 与保留的 `agent-registry.local.tsv` 汇总 `{Id,Label,Exe,Source}`；仓库 `agent-registry.tsv` 清空产品行只留协议。Init/F3 的 definitions/peers/wizard CLI、F6 Lua 运行时选择器、Installer Doctor/首绑定、Sidebar/open-project 全部改读同一开放清单；Init 冷启动必重扫，`r` 同时清 definitions/peers；未知 Agent 用通用 PowerShell host 在项目 cwd 启动，已有会话读取/续聊分支仅作为可选 adapter，不再控制候选资格或未知回退。UI：`Write-BoxGridRow` 让 COMMAND 三行共用 40%/34%/余宽三列；删 `[d] dash(grok)` 显示/处理、launch.lua Dashboard 分支和启动菜单项，启动菜单只余 Init/PowerShell/CMD。写出方不再暗补 grok，动态 route 或两列 legacy 均可。回归：(1) 当前机无配置自动由 npm `@openai/codex` 描述识别 `Codex`；(2) 临时 `mock-dynamic` 本地 TSV 在新 Init 进程 AGENT 区出现、清理后消失；(3) 代码从未出现的 `orbit-ai` 仅凭临时 npm 描述 “AI coding agent” + bin 自动命中，证明非换皮白名单；(4) installed Init `q` exit 0/Codex present/Dashboard absent；PS parse 全 0、bootstrap BOM 保持、WezTerm `ls-fonts` exit 0、load guard 无警告；安装器 Doctor ready，live↔`~\.config\wezterm` 19 对同步文件 SHA-256 全一致，本地 registry 0 行且第二次安装确认保留。安装备份：`~\.config\wezterm.bak-20260815-015058`。待用户重启 WezTerm 终验真实列对齐/启动菜单/F6。
- 2026-08-15: **D-015 新建向导四步化。** 删除独立 Default agent 步，将 Step 3 改为 Agent / CLI 单一选择：选择 ID 同时决定首次启动与 desk-roots 第三列，PowerShell-only 显式记为 `shell`、不伪造 grok；确认页只显示一组 AGENT/CLI 身份。位置手输父目录仅接受 `[0]`，同步清除 `[9]` 的 UI、解析、错误提示与教学。自动冒烟覆盖 Codex→codex、PowerShell→shell、输入 9 被拒、无第五步；PS 解析/配置 load guard/项目验证通过，live↔镜像哈希一致。待用户 F3 live 冒烟。
- 2026-08-14: **侧边栏不可点击根查明 + D-014 落地：单击开链接恢复 + launcher 扩展结构性去链接。** 根因：非代码回归——发射链路（OSC-8/Write-ClickablePath/字节结构）实测完好，是 08-09 的硬化把普通单击改为只完成选区（当时的动机是误点 .cmd/信任目录），Ctrl+Click/中键一直是唯一入口，用户体感为「又不能点了」。修复（用户指令）+ 加固双轨：(1) options.lua 左键 Up 改 `CompleteSelectionOrOpenLinkAtMouseCursor`——拖选语义保留、单击链接直接打开（已用 show-keys 实测该 action 在本机 wezterm 20240203 真实注册）；(2) sidebar `Write-ClickablePath` 加 launcher 扩展护栏（.exe/.cmd/.bat/.com/.scr/.reg/.vbs/.vbe/.lnk/.msi 渲染为纯文本不生成链接），可执行对象只能键盘 `o N` 显式打开——原始误开顾虑被结构性消除，而非靠禁用交互。审查：全仓 OSC-8 发射口唯一化确认（sidebar 三调用点全覆盖）；hyperlinks.lua 安全扩展白名单复核无双击执行面；`swallow_mouse_click_on_pane_focus=false` 使未聚焦侧栏首击即开（顺带聚焦），符合直觉。回归：test-sidebar-link.ps1 新用例 ALL PASS（普通文件 OSC-8 结构良好 / 4 个 launcher 扩展零链接 / 目录仍可点）；bom-and-parse 重挂 parse 0×2；真实配置 ls-fonts exit=0 + show-keys 6 处注册；options.lua 配平 OK；live↔镜像 md5 一致。**待用户 live 终验**：wezterm 完全重开（options.lua 是模块文件，自动重载不盯）后——侧栏单击文件/目录名直接打开，.cmd/.exe 行仍为纯文本，拖拽选择文字不受影响。

- 2026-08-14: **P-011 加固 R2 施工完成 + 全量回归绿 + 推送远端。** 施工范围 = 用户批准的全量（M2-1~M2-5 全修、M2-6 按 A 移除三个裸 agent @ home 入口、L2-1/2/3/5/7/9 随清；L2-4/6/8 留观察）。bootstrap.ps1：M2-1 两处数字分支 `$line.Length -gt 4` 上限 + StatusHint/ScreenDirty（step-2 本就 TryParse 无患，回归实证）；M2-2 Find-AgentExe kimi/codex/deepseek 空环境变量护栏 + Build-InstalledAiCliOptions 条件数组；M2-4 向导 spawn 改用已解析 `$Exe` 全路径；L2-2 两个 Read-Host 后 `$null -eq $line → break`（EOF 防死循环）；L2-3 非 shell 分支补 R1 复验；L2-5 `r` 键清 `$script:AgentPeers` 缓存；L2-1 splash 注释 Magenta 归位；L2-7 splash 令牌改罕见串 `__WZ_SPLASH_*_7F3A__`；L2-9 零 agent 提示补 deepseek。Install-WZ.ps1：M2-3 Resolve-AgentExe deepseek 分支 + Doctor/绑定列四平权 + 注释；M2-5 四处 Yellow 归位（Write-Warn/Next steps/警告行 → DarkCyan/Cyan）。open-project.ps1 三处 + profile-snippet/cheatsheet/load_guard 各其位 Yellow/DarkYellow → DarkCyan/Cyan。launch.lua：M2-6(A) launch_menu 删 ◆ Kimi/◎ Codex/◇ DeepSeek @home 三块（保留 Init/grok dashboard/PowerShell/CMD）。回归：BOM 重挂 parse 0×2；管道冒烟 q / 2qq / 99999999999（得「number too long」提示而非红错误）/ 空 stdin（干净退出不空转）/ step-2 超长（TryParse 优雅「no such agent」）exit 全 0；零 agent S1/S3 渲染干净 + 兜底提示 + not found；宽度模态 psw=100 仅回显行偏差；lua 配平 10/10；splash 单测 ALL PASS×2；ls-fonts exit=0；live↔镜像 10 文件 md5 全一致；残留 Yellow 终审全部为输入前缀（wz>/agent 1-N/explorer>/wizard 提示符）= D-013 有意保留。**待用户 live 终验**：启动菜单只剩四个干净入口；超长数字手滑不再脏屏。

- 2026-08-14: **加固审查 Round 2 完成（P-011 草案，只审未改）。** 范围 = P-008 收口后全部新改动（DeepSeek 接入/启动动画/D-009 静态屏/D-010 组合/D-011~D-012 页签链/性能修复/D-013 两轮）。方法：逐函数精读五条热路径 + 四个横切面 + lua 全模块 + 仓内辅助脚本。结论：**高危 0**（无新门禁绕过；R1–R6 在四 Start-*Tab 与 F6 选择器链全部在位；引号转义链逐点核无注入面）；**中危 6**：M2-1 超长数字输入 Int32 溢出崩面板（主循环无护栏）、M2-2 Find-AgentExe 空 LOCALAPPDATA 无护栏（D-006 同族漏网）、M2-3 Install-WZ 不识 deepseek（装机断档）、M2-4 向导 spawn 用裸命令名忽略已解析 $Exe、M2-5 D-013 未清扫仓内辅助脚本（警告黄残留 9 处）、M2-6 启动菜单裸 agent @ home 与 D-003 精神冲突（**需用户裁决 A 移除 / B 标注逃生舱**）；**低危 8**（注释陈旧/EOF 空转/纵深防御/HUD 角色识别/缓存失效/-NoExit 不对称/令牌链替换/splash 贴底漂移）。报告：`docs/hardening-review-2.md`。待用户圈定施工范围后按 M2-1→M2-2→M2-3→M2-4→M2-5→L 批清推进。

- 2026-08-14: **D-013 精化：框框/表头禁黄 + 输入前缀亮黄定为全局通用设计。** 用户两点裁决：(1) init 页的框框和表头不要用亮黄（颜色污染）；(2) 侧边栏 `explorer>` 输入前缀亮黄是好设计，定为全局通用。施工：bootstrap.ps1——COMMAND 区 `$bCmd` Yellow→DarkGray（框+标题归位，黄芯片成为区内唯一输入信号），`>_ step N ACTIVE` 字段行从整行黄拆为 ` >_` 标记黄 + 状态文本 White（Write-BoxKeyRow 分段着色），wizard `Read-LinePrompt` 提示符 Cyan→Yellow（输入前缀家族归一：`wz>`/`agent N`/`explorer>`/wizard 提示/` >_`），`Write-UiChoice` 默认 `-Fg` Yellow→White（19 个调用点全部显式传色，零行为变化，防未来裸调用漏色），配色注释块重写为 D-013 标准；sidebar.ps1——COMMAND `$bCmd` + Show-Help KEYS 框 `-Border Yellow`×10 + `Write-BoxKeyParts` 默认参数全部归 DarkGray，` >_ ` 标记 White→Yellow。**修正记录偏差**：Init LIST/AGENT 芯片的 8-13 阶段高亮（激活步骤亮黄/非激活暗灰）代码事实为**保留**，D-013 记录与 MAIN §2/键位表/B4 表述已对齐（此前误记为废除）。status.lua 品牌徽章（★ AI STAR CUBE 金底 #f9e2af）属徽章式标识、位于页签条而非终端内容区，不在本标准约束内，未改。验证：BOM 重挂 parse 0×2；管道冒烟 `q`/`2qq` exit 0、模态 psw=100 仅回显行偏差；live↔镜像 10 文件 md5 全一致；剩余 Yellow grep 终审全部 = 键位芯片/输入前缀/阶段高亮激活芯片。**待用户 live 终验**：COMMAND 框暗灰后黄芯片更突出；向导提示符亮黄；侧栏帮助屏（`?`）框不再黄。

- 2026-08-14: **D-013 颜色标准落地 + deepseek 猫条残留修复 + 存量乱码清除。** (1) **残留修复**：DeepSeek CLI 是行式 REPL（无全屏 TUI），启动动画播完留在屏幕上（用户截图红框）；grok/kimi/codex 的 TUI 首帧会盖住动画故无感。修复：`Get-AgentSplashScript` 动画循环结束后统一 `[Console]::Clear()`（try/catch 兼容重定向宿主），四家拉平为「播动画 → 清屏 → 进 agent」。(2) **D-013 施工**：用户裁定亮黄为唯一可输入色并全局预留。bootstrap.ps1——`Write-UiChoice` 结构强制（索引芯片恒 Yellow、标签恒 Gray，`-Fg` 仅对无芯片行生效，新增选择行不可能错色）；盒原语默认边框全部 DarkGray（Write-BoxKeyRow 原 Yellow 默认值已改，现存调用点均显式传 -Border，无行为变化）；splash 猫+进度条 Yellow→Magenta（装饰让位）；loading 行 Yellow→Cyan；wizard 信息行 Yellow→Cyan/White 共 9 处 + DarkYellow 清零→DarkCyan；`wz>`/`agent 1-N` 行输入提示符改亮黄。sidebar.ps1——信息行 Yellow→Cyan/White、DarkYellow×6→DarkCyan、`explorer>` 提示符亮黄保留。复查 grep：剩余 Yellow 全部为合规的输入可供性（序号芯片/键位芯片/输入提示符/COMMAND 输入区框架）。(3) **存量乱码**：bootstrap.ps1 两行历史双重编码 `鈥?`（commit 2169798 带入，wizard 边界路径 2546/2591 行）→ ASCII `-`；码点签名扫描其余 5 文件（sidebar/cheatsheet×2/open-project/Install-WZ）全干净。验证：BOM 重挂 parse 0×2；splash 包装单测 ALL PASS；管道冒烟 `q`/`2qq` exit 0、模态 psw=100（偏差仅输入回显行）；lua 配平 10/10；ls-fonts exit=0；live↔镜像 10 文件 md5 全一致。**待用户 live 终验**：① 四 agent 启动先见 Magenta 猫动画、播完清屏无残留；② Init/wizard/sidebar 一切可输入索引统一亮黄；③ DeepSeek 402 Insufficient Balance——账户需充值后对话可用。

- 2026-08-14: **F-014 DeepSeek CLI 接入 + 启动屏动画化 + 一次 BOM 回归事故。** (1) **安装**：DeepSeek 无官方 CLI，装社区版 `@kavienw/deepseek-cli` v0.5.0（用户明确授权）；首次误落 Kimi 托管 npm 前缀（`NPM_CONFIG_PREFIX` 环境变量继承坑），已卸并以 `--prefix %APPDATA%\npm` 重装——该目录在用户 PATH，新生 shell 可直接解析 `deepseek`。(2) **平权接入**：bootstrap.ps1 加 Find-AgentExe 分支（PATH + `%APPDATA%\npm` 显式回退）、peers 第 4 位（稳定序 grok/kimi/codex/deepseek）、`Start-DeepSeekTab`（kimi 式 cwd 身份 + codex 式 shim host wrap + 猫条前置）、Invoke-AgentLaunch 分支（resume=`--continue`）、`Read-DeepSeekSessionSummaries`（哈希探测绑定项目会话，PS↔Node sha256 对拍一致含 CJK）、wizard 注册表/Step 4/`Start-ProjectWithCli` 分支；lua 侧 status/launch/layouts/resume/desk/projects 全接入（AGENT_EXE_NAMES、agent_args `--continue`、agent_label、launch_menu ◇ DeepSeek、installed_agents 第 4 位、AI·DeepSeek 标签、`.deepseek-cli` 为工具目录）；open-project.ps1 `-Agent deepseek` + `-Continue` 映射。顺修：codex Find-AgentExe 回退加 WinGet Packages glob（本机真实落点 `OpenAI.Codex_*\codex.cmd`，旧硬编码三路径全失效，live 仅靠 PATH 幸存）。(3) **启动屏动画**（用户：要的是 Init 那只走路猫，不是静态卡）：`Get-AgentSplashScript` 重写为 5 帧走路猫 + `█/░` 进度条 0→100%（帧间 75ms、末帧不 sleep，约 300ms 固定窗；单 Yellow 色系；`SetCursorPosition` 原地重绘），wizard `Start-ProjectWithCli` 同享。**重定向宿主锚点教训**：`[Console]::CursorTop` 在无控制台时抛异常——首版把取坐标与 Write-Host 放同一 try，导致重定向下整帧被吞（单测当场抓获）；现拆为 `$__redir` 预检 + 独立 try，重定向=静态单帧。(4) **BOM 回归事故**：收尾的 "scanning…deepseek" 一行编辑后忘跑 bom-and-parse，live 文件无 BOM 被 PS 5.1 按 GBK 误读 → 用户实测 parse 炸在 3031 行。规程重申：**bootstrap.ps1 的任何编辑之后、任何其它验证之前，第一件事必须是 bom-and-parse**；validate_project 的 BOM 断言本就是为此设计（本轮它也在收口时抓到了 cheatsheet.txt/open-project.ps1 两处）。验证：BOM 全量重挂 + parse 全 0；splash 单测 ALL PASS×2；管道冒烟 q/2qq exit 0、框线模态 psw=100、AGENT 区四行稳定序、step-2 arm/取消正常；ls-fonts exit=0；lua 配平 10/10；哈希对拍 MATCH×3；live↔镜像 8 文件 md5 全一致。**待用户 live 终验**：四 agent 启动先见动画猫条；deepseek 首启录 key；无周期卡顿。

- 2026-08-14: **D-012 首轮落地后的性能回归根治 + agent 启动 splash 补全。** 用户实测「整个启动都变卡非常多（init 启动、项目启动）」+「打开 kimi 以外的 agent 猫猫读条不出现」。根因：(1) **钉住实现的性能税**——`pane_is_init` 在每次页签重绘波对每个页签做 `mux.get_pane` + `get_foreground_process_info`（Windows 进程快照，GUI 线程内），4s TTL 过期即全员重扫 → 整个终端周期性卡顿。修复：预过滤只吃快照免费字段 `foreground_process_name`（非 powershell/pwsh/cmd 直接 false，agent 页签零开销）+ TTL 30s + 进程名变化即失效；稳态重绘只剩字符串比较。(2) **0.6s 死等**——Start-*Tab 的 `Start-Sleep 0.6` 原为让人读 OK 行，D-012 后页签即启即关、纯废时 → 200ms（每次启动省 0.4s）。(3) **猫猫读条补齐**（兑现 8-13 22:56「所有脚本 loading 都要猫」）：三个 Start-*Tab 的 spawn 统一改走 `powershell -NoLogo -Command` 包装（`Get-AgentSplashSpawn`/`Get-AgentSplashScript`）——先瞬时绘制静态猫猫启动屏（`/\_/\
( o.o )` + 项目·agent + starting...），同一控制台立即启动 agent CLI，**零新增延迟**，agent 首帧自然覆盖 splash；kimi 原来自带开屏、其余两家黑屏数秒的问题拉平（平权）。codex shim 路径保留 -NoExit 语义（错误可见），splash 前置于其 psCmd；grok/kimi 无 -NoExit（agent 退出即关页签，与直启 parity）。包装 argv0 恒为真 powershell.exe，无 .cmd shim 冻结隐患；splash 文本不含 bootstrap.ps1/wz-init 字样，不触发 Init 误检。验证：splash 单测全 PASS（活文件提取助手函数 → 假 agent 端到端：猫猫/标签/agent 行全渲染 + 引号边界）；BOM 重挂 parse 0；管道冒烟 `q`/`2qq` 行宽全等 psw=100；`ls-fonts` exit=0；load guard OK；live↔镜像 bootstrap.ps1/status.lua md5 一致；validate + readiness --verified OK。**待用户 live 终验**：wezterm 完全重开后——① 全程应不再周期性卡顿；② 启动 grok/codex 应先见猫猫启动屏再进 CLI；③ 启动成功 Init 页关闭。

- 2026-08-14: **污染三连根查明，路径 2 落地（D-012），路径 1 按用户授权放弃。** 对抗性分析结论：(a) 昨晨的「完全不行」= 三个独立机制叠加——① 10:14 的污染来自**旧版** bootstrap 的宽松 `(\d+)` 抓取（无日志可留，无法复盘具体错号）；② 「第二个新建 Init 页叫 Shell」= Ctrl+T/「+」走 default_prog 出生无 `set_title`，`tab_tool` 见 powershell 进程 → Shell；③ 昨晨的 user-var 钉住**从未生效**——wezterm 自动重载只盯主 config 不盯模块文件，且 PaneInformation.user_vars 未验证，新 status.lua 根本没被加载。调试日志佐证新写入侧无恙：10:33 "find | Codex" → pane 2 严格改名正确，self=0 未被触碰。(b) 路径 1（长命 Init + 钉住）要四层永远成立（写入卫生 × 显示检测 × 重载纪律 × 出生标题），任一失守即复发——不稳固，按用户指示放弃为主方案；其有效残件（argv 显示钉住）并入 D-012 服务短命 Init 的存活期正名。(c) **路径 2 结构性消除污染目标**：启动成功即关 Init 页，无可污染之物；q/失败/门禁全保留 Init。施工：Start-*Tab 成功返回 `$true`、Invoke-AgentLaunch 透传、Complete-AgentPick 成功即 `Close-CurrentWezPane`（无 wez/pane 时降级重绘不 exit）；status.lua 改 argv 检测 + 4s TTL 缓存；撤除 OSC emit 与 Assert 回钉；cheatsheet 流程行补关闭行为。验证：BOM 重挂 parse 0；管道冒烟 `q` 与 `2/q/q`（取消不关页签）行宽全等 psw=100；`ls-fonts` 真实加载 exit=0；load guard OK；live↔镜像 bootstrap.ps1/status.lua/cheatsheet.txt md5 一致；validate + readiness --verified OK。**待用户 live 终验**：启动任意任务 → Init 页签随之关闭、落点在 agent 页签；Ctrl+T/F3 新建 Init 应显示 "Init" 而非 "Shell"（注意：status.lua 改动需 wezterm 完全退出重开或触发配置重载才生效）。

- 2026-08-13: **23:32 三连修复 + 对抗性审查完成。** (1) **页签污染** → `D-011`：四个 Start-*Tab 块旧逻辑为 `wez cli spawn 2>&1`（stderr 混入数字正则可能抓错 paneId）且 paneId 缺失时 fallback 到不带 `--pane-id` 的 `set-tab-title`（改名打到当前 Init 页签）；新增 `Set-SpawnedTabTitle` 硬门禁统一 4 个调用点。(2) **序号芯片紧凑化**：默认视图 `[ 1]`→`[1]`（用户：个位数不需要多空格），仅 ShowAll 保留两位补齐 `[12]`；AGENT 区 `[ 1]`→`[1]`。(3) **右缘爆格子根治**：根因为结构性——行渲染的芯片前缀（缩进 2 + 芯片 4 = 6 字符）在 Update-ColLayout 里只记账 4，每行恒超框 2 格，窄宿主下收缩级联失败更惨（实测重定向输出 行 113 vs 框线 83）。修复：`$num` 改为含缩进的全宽（默认 6 / ShowAll 7）、表头 `[#]` 宽度跟随、Project 列收窄（`Min(22, Max(14, U*0.14))` 把空间让给 Title）、收缩级联加 path→24/proj→14 兜底、内容带 70%→**86%**（用户：延长右边区间）、`Write-BoxKeyRow` 加 `Limit-Display` 硬截断（右 `|` 永不出框）、日期占位 `---- -- --:--`（13 字符恒被截成 `---- -- ~`）→ `---- -- --`、date 收缩下限 9→10 保住占位。(4) 顺修：`Update-LoadingBar` 在重定向宿主下跳过重绘（猫猫读条 live 不变，管道冒烟不再产出巨行）。**对抗性审查**：管道冒烟三态（初始/step2 arm/ShowAll 18 行含 `[10]`–`[18]` 与 CJK 标题行）**全部内容行显示宽度精确一致**（psw=100，Python 等宽表逐行实测，此前为 83/113/81 混杂）；BOM 重挂 parse 0；live↔镜像 md5 一致；validate_project + readiness_check --verified OK。残留说明：COMMAND 区含 `→`/`·`（东亚歧义宽字符），本表与 WezTerm 默认（ambiguous=narrow）一致，若用户字体配置不同可能出现 1 格级参差，届时换 ASCII 即可；页签修复无法脚本复现，**待用户 live 验证**（启动任务后 Init 页签应保持 Init）。

- 2026-08-13: 用户批准 P-010 → `D-010` 并施工完成。默认视图封顶 9 行（任务号恒个位）；两位数组合 `<任务><agent>` 一次直启（`n<组合>` 强制新会话），门禁照常；`a` 全量视图组合自动失效（18 行，两位数=行号，零歧义）；单个数字仍走两步慢道。UI：header 视图标签区分 `combo on/off`，COMMAND 输入行与键位行教 `<t><a>` 语法。管道冒烟：`19`→agent 位越界提示 ✓；`a→12`→按行号处理命中弱路径门禁 ✓（未误启动）；parse 0 错误（BOM 已重挂）。

- 2026-08-13: **序号制式统一 + 阶段高亮 + 行走猫读条**（用户截图红框指示）。(1) 两个选择区的序号统一为 4 位方括号芯片 `[ 1]`/`[12]`（表头 `[#]`），同一左缩进（x=6），色系全局唯一：**亮黄 = 当前激活步骤的可输序号，暗灰 = 非激活**；黄色从此只给可输入序号/键。(2) 阶段指示（用户认可的「状态转换时重绘一次」方案 2a）：第 1 步 LIST 芯片亮黄/AGENT 暗灰，待命后反转；区标题带 `<< step N` 标记（`1 LIST << step 1 · type task number` / `2 AGENT << step 2 · pick agent for X`）；COMMAND 输入行同步显示当前 ACTIVE 步骤。行渲染从单色 Write-FullLine 升级为 Write-BoxKeyRow 分段着色；序号列从列布局中独立成芯片段。(3) 加载读条升级为 **5 行行走猫**：3 行 ASCII 猫（`( o.o )`/`( -.- )` 两帧交替）随进度向右走 + 40 格宽 `█/░` 条 + 百分比/计数/阶段标签，写入绝对 Y 原地动画。管道冒烟：芯片对齐 ✓、阶段标题反转 ✓、猫块动画帧 ✓、arm→取消→退出零 spawn ✓。parse 0 错误（BOM 已重挂）；live↔镜像 md5 一致。**组合输入（2b，如 `13`=任务1+agent2）经分析列为 P-010 候选待用户定夺**，未实现。
- 2026-08-13: **Init 抖动终局：D-009 静态屏 + 行输入**。渲染器 v2（无清屏覆写 + [Console]::Write 直连）用户实测「跟上个版本没区别」——确认 ConPTY 宿主下逐键重绘不可救，按用户预授权退路执行：废除 ReadKey 逐键循环、AgentCursor、NumBuf、行选中高亮与 Begin/Flush-Frame 帧机制；主循环改 `Read-Host` 行输入（`wz>` / `agent>` 两个提示符承担两步，文法同构：数字+Enter 选 / 空 Enter=默认 / q 返回；`n<num>` 强制新会话）；Show-Screen 加 `ScreenDirty` 闸——只在状态转换时整屏重绘一次，空 Enter 与键入过程零重绘。**管道冒烟通过**（重定向宿主直接可跑）：`zzz→q` 正常渲染+未知命令提示+退出；`1→9→q→q` 完成 arm（2 AGENT 区标题随待命项目变化）→非法 agent 号提示→取消→退出，全程零 spawn、零崩溃。parse 0 错误（BOM 已重挂）；live↔镜像 md5 一致；cheatsheet 同步（Init 行输入 + F6 先选 agent）。手感待用户最终确认。

- 2026-08-13: **Init 抖动根治 v2**——v1 行级 diff（绝对坐标逐行定位 + Write-Host 分段写）实测**闪烁更厉害**，用户反馈后当日推翻。v2 改为**整帧顺序覆写、稳态零清屏**：认识到闪烁根源是「先刷空白再重绘」的空窗期而非重绘本身，`Begin-Frame` 不再调用 `Reset-Screen`；`Flush-Frame` 从 (0,0) 顺序覆写全部行（行均已补齐宽度，无残留），输出走 `[Console]::Write` 直连（Write-Host 宿主往返是慢路径）；清屏只发生在帧缩短/resize/首帧/重建/启动动作后（仅补尾行或全清一次）。教训记入工程经验：PS 5.1 + WezTerm 下「绝对坐标局部更新」不可靠，「无清屏覆写」才是稳态正解。parse 0 错误（BOM 已重挂）；live↔镜像 md5 一致。手感待用户确认（j/k 连按、数字、arm 往返）。
- 2026-08-13: 用户批准 D-008（agent 平权选择 + 交互同构）并施工完成。(1) **Init 两步同构**：新增 `$script:AgentCursor`/`$script:NumBuf` 共享状态；第 1 步 LIST——数字键入缓冲（废除 `wz> N` Read-Host 路径）、Enter 确认数字跳转或当前行 arm、Esc 先清缓冲再退面板；第 2 步 AGENT 区——arm 时光标落在路由默认 agent 上，j/k/↑↓ 在已装 agent 内环绕移动（行渲染 '>' 光标 + Yellow 高亮）、数字缓冲 + Enter 按号选、Enter 直按 = 默认、Backspace 退格、q/Esc 取消零 spawn。第 2 步提示行改 `'j/k or arrows = move · Enter = confirm · digits+Enter = pick · q/Esc = back'`；COMMAND 输入行显示共享缓冲 `' >_  <digits>'`，`[0-9]` 键提示改 `num+Enter`。(2) **F6 平权选择器**：layouts.lua 新增 `pick_agent`（`act.InputSelector`，fuzzy=off，全量已装 agent、默认=D-005 路由排第一带 ▶ 标记，Esc 取消零 spawn；单 agent 跳过、零 agent toast）；`open_workbench_fresh` 重构为强路径门禁 → pick_agent → 回调 spawn（spawn 体抽成 `spawn_workbench_fresh`）；gate_spawn 的 agent 腿对 F6 不再适用（选择器内任一已装 agent 均可选），dual/review/focus 死路径保留原门禁不加选择器。验证：bootstrap/sidebar PS parse 0 错误（BOM 已重挂）；10 lua 块配平 OK（同步后镜像复核）；wezterm_load_guard OK；live↔镜像 md5 一致。**手感冒烟待用户**（两步同构、F6 选择器、Enter=默认、Esc 零 spawn）。

- 2026-08-13: 验收清单对比实测顺手修复：`Install-WZ.ps1` Doctor 在精简环境（spawn shell/CI）直接崩——`Resolve-AgentExe`/`Resolve-WezExe` 对可能为空的 `$env:LOCALAPPDATA`/`$env:ProgramFiles` 直接 `Join-Path`，且 `$env:OS` 为空被误判为非 Windows。全部加空值护栏（与 bootstrap `ProgramFiles` 护栏同族，归 D-006 范畴）。修复后正常环境模拟实跑 **Doctor: ready 全绿**（codex 未装/WZ_PROJECTS_ROOT 未设为提示级 `!!`，不阻塞）。BOM 重挂、parse 0。

- 2026-08-09: Corrected `F-004` Leader chord to **Alt+z** (was documented as Alt+;); aligns with live `keys.lua` and PORTABILITY audit.
- 2026-08-07: Initialized `M-001` and `M-002` as active project method constraints.
- 2026-08-07: Separated product root from PPS clone; added `M-003`, `F-001`–`F-005` from recovered morning work and user protocol clarification.
- 2026-08-07: User approved `D-001` (name WZ-AiWorkBench) and `D-002` (workbench-first; skill packaging deferred).
- 2026-08-07: Added `F-006` — Explorer/AI task-root sync + clickable default-open in sidebar.
- 2026-08-09: Added `D-003` / `F-007` / `F-008` — project name definition, hard gates, create-flow path freeze; purged home/Desktop from desk-roots.
- 2026-08-09: Added `F-009` — Install-WZ.ps1 portable third-party install; fixed hard-coded G: default parent.

- 2026-08-09: Added `F-010` — multi-model takeover of the same task not provisioned in existing design.
- 2026-08-09: Added `F-011` — Kimi Code CLI launch/resume facts (no `--cwd`; `--continue` cwd-scoped); P-007 full design drafted in MAIN §Multi-model handover.
- 2026-08-09: User approved P-007 → `D-004` (multi-model handover design); implementation slices started.
- 2026-08-09: D-004 slices 1–3 landed in live config + repo mirror (agent column, `-Agent`, HUD, wizard step, kimi in CLI registry); scripted handoff smoke passed (`prototypes/handoff-smoke/`). Interactive smoke pending user session.
- 2026-08-13: Init panel lag fix — row cache + dirty flag in `bootstrap.ps1` (was: full session-directory rescan per keystroke); live + mirror synced.
- 2026-08-13: Init list fixes — Act* now counts kimi wire.jsonl / codex rollout events (was grok-only, others always 0); bound layer reordered by last activity desc with no-session tasks last (was desk-roots binding order); no-session/fav rows no longer fake `Updated=now`; Index renumbered after ordering. Live + mirror synced; PS parse 0 errors; ordering logic smoke-passed.
- 2026-08-13: User correction — Act* per-agent counting violated agent 平权; **superseded** by uniform rule: Act* = project folder size for every row (strong paths only; PS 5.1-compatible `Get-ChildItem -Recurse` after `EnumerationOptions` proved unavailable on .NET Framework). DETAIL meta shows `size:` instead of `msgs:`. Parse 0 errors; size fn smoke-passed; live + mirror synced.
- 2026-08-13: Uncapped folder-size scan made Init open hang on huge trees (game/Unity projects) — **superseded** by time-bounded `Get-ProjectContentMark` (80ms/folder, 1500ms total; truncated rows show `+` suffix) + `Show-LoadingScreen` before every rebuild so loading is explicit. Smoke: all 9 desk-roots sized in 512ms total. Parse 0 errors; live + mirror synced.
- 2026-08-13: User rejected time-budget truncation (distorts relative size, e.g. `30M+` could exceed `300M+`) — **superseded** by final design: Act* = EXACT folder size served from cache (`project-marks.tsv`), computed by detached hidden refresher `project-marks.ps1` (PID-guarded, atomic temp+move write); uncached rows show `…` and auto-trigger refresh; staleness window 10 min. Loading upgraded to progress bar: cat kaomoji frames + `█/░` bar + per-stage counts fed by all three session readers. Fixed latent encoding hazard: `bootstrap.ps1` was BOM-less UTF-8 misread as GBK by PS 5.1 — new non-ASCII chars broke parsing; file now carries UTF-8 BOM, parse errors=0. Smoke: refresher end-to-end 402ms/2 projects exact; cache parse + size format verified; live + mirror synced.
- 2026-08-13: First-fill UX gap closed — '…' rows previously waited for manual `r`; main loop now idle-polls (`KeyAvailable` + 250ms sleep) and `Sync-ProjectMarksFromCache` patches pending rows from cache the moment the refresher lands (≤250ms, auto re-render). NOTE: the Edit toolchain strips the UTF-8 BOM on write — after any edit of `bootstrap.ps1`/`project-marks.ps1`, re-apply BOM before parse-checking (PS 5.1 reads BOM-less as GBK and CJK content can break parsing).
- 2026-08-13: User-directed Init rework — (1) Act* column + entire marks pipeline (cache/refresher/idle-poll/`project-marks.ps1`) **removed** ("优化不出效果"); list is now `# DateTime Tag Project Path Model Title` with Path head-kept/`~` tail-truncated. (2) DETAIL middle block + `i` key + dead helpers (`Get-ProjectStateHint`/`Format-RelativeTime`/`Write-BoxWrapped`/`Show-RowDetail`) removed. (3) **Launch–agent decoupling made the core interaction**: Enter/n now always open `Read-AgentChoice` (default = session agent → task agent → first installed; resume/new annotated; R-gates unchanged) → `Invoke-AgentLaunch`. Main loop restored to blocking ReadKey. Parse 0 errors (BOM reapplied); live + mirror synced; marks files deleted.
- 2026-08-09: Fixed D-004 gap — Init panel never enumerated kimi sessions (grok-only scan) and Enter hardcoded grok resume. Added `Read-KimiSessionSummaries` + agent-routed `Start-KimiTab` (`kimi --continue`, spawn cwd = task root per F-011) in live `bootstrap.ps1`; WZ_Skill row bound to `kimi` in desk-roots 3rd column; mirror synced (md5 identical); parse errors 0; smoke-kimi-sessions ALL PASS.
- 2026-08-10: Added `F-012`（codex 启动/续接手事实，本机实测）与 `D-005`（agent 平权与缺省解析，用户指示）。完成对抗性去 grok 耦合改造：F6/续聊/布局族按 agent 路由（修 F6 写死 grok、resume 只支持 grok 两个核心断点）；codex 会话枚举 + Init 三路路由 + `Start-CodexTab`；sidebar `Start-AgentHere`、profile/cheatsheet/README 平权；Install-WZ Doctor 任一 agent 即可、open-project 缺省解析 D-005、guard 正则泛化。wezterm 配置加载 OK、load guard OK、7 个 ps1 解析 0 错误、smoke-kimi/smoke-codex ALL PASS、live↔镜像全量 diff 一致。交互冒烟待用户。
- 2026-08-13: **上轮（8-13 Init 改版）三故障根因与修复。** (1) Enter/n 的 agent 二次选择器从未弹出、一切启动静默回退 grok：`Read-AgentChoice` 读取的 CLI 注册表（`WzCli*`）只在新建向导 Step 3 构建，正常 Init 路径恒为空 → `ids.Count -eq 0` → `return 'grok'`。修复：新增 `Get-InstalledAgentPeers`（经 `Find-AgentExe` 自探测 grok/kimi/codex、进程内缓存），选择器与 Build-Rows 共用，不再依赖向导注册表。(2) Init 打开慢（实测端到端 2.66s）：三路会话全量同步扫描，且 codex CLI 已卸载仍每次递归扫描 47 个残留 rollout（约 538ms）。修复：会话读取器按「已安装 agent」门控 + codex rollout 按 mtime 截断 newest 60；端到端降至约 1.7s（-35%）。(3) 顺修 `$env:ProgramFiles` 为空时启动红字报错。冒烟：peers=grok,kimi（codex 正确排除）；选择器默认 WZ_Skill→kimi、kimi 会话行→kimi、未绑定→grok（D-005 首装序）；Build-Rows 1600→797ms；PS parse 0 错误（BOM 已重挂）；live↔镜像 md5 一致。交互冒烟待用户。
- 2026-08-13: **用户否决第二选择屏，改为同屏展开**（「不出现二次界面…1次+2次选择都通过同一屏」）。`Read-AgentChoice` 整函数删除；每个 bound/fav 项目行就地展开本机已装 agent：主行 LaunchAgent=会话 agent→desk-roots 第三列→首装序（D-005），下挂 ALT 行=其它已装 agent 强制新开；Enter/数字直接启动该行，n=该行 agent 强制新会话；行新增 `LaunchAgent`/`ForceNew` 字段，`Invoke-RowPrimary/NewSession` 直发 `Invoke-AgentLaunch`。顺修潜伏断点：grok `summary.json` 的 `agent_name` 是 profile 名（`grok-build-plan`），读取时归一化为 `grok`，否则 resume 匹配恒失败。`MaxRows` 18→26；cheatsheet 同步。冒烟：18 行=9 主+9 ALT，WZ_Skill=resume(grok)/ALT kimi、find=resume(kimi)/ALT grok；端到端约 1.9s；parse 0 错误；live↔镜像 md5 一致（bootstrap.ps1 + cheatsheet.txt）。
- 2026-08-13: **用户再次修正：不要行级展开，要常驻 AGENT 区**（「仍旧是分两步进行选择和确认，模型提前显示在界面内，划分一个独立的区域」）。ALT 行展开撤除（恢复单任务单行、MaxRows 回 18）；Show-Screen 新增常驻「2 AGENT」区（Magenta 边框）：列出已装 agent + 对当前/待命行的 resume|new 标注 + (default) 标记。两步模态：第 1 步 LIST 选行 Enter/n → `PendingRow` 待命（只重绘不重建行）；第 2 步数字=选 agent、Enter=默认（行 `LaunchAgent`）、q/Esc=取消 → `Complete-AgentPick` 启动。待命时其余键吞掉（模态）。待命标题 `<< pick agent for <项目>` 与操作提示行现场确认通过；端到端约 1.9s；parse 0 错误；live↔镜像 md5 一致。
- 2026-08-13: 完成 `P-008` 全面兼容性/加固审查（仅分析，未改任何代码）：报告 `docs/compat-hardening-review.md`。发现 3 高：H-1 `layouts.lua` 四个布局函数 spawn 前无 R1 门禁（`open_dual_ai`/`open_review`/`open_focus_agent` 完全未检查，`open_workbench_fresh` 门禁在 spawn 之后）；H-2 `sidebar.ps1` `b` 键/`Write-DeskRootToFile` 无 R5 弱路径+保留名检查，构成绕开 `desk.lua set_root` 的侧门；H-3 `desk.lua write_map` 与 `sidebar.ps1 Write-DeskRootToFile` 在 agent=grok 时丢 desk-roots 第三列，违反 D-005 显式写出规则。另 5 中（lua 侧不查 kimi/codex 可执行性兜底、desk.lua read_map 无缓存高频读盘、open-project 硬编码 WezTerm 路径+cli 文本解析、launch.lua 配置加载期 PATH 全目录 io.open、sidebar 事件Action 跨 runspace 存疑需实测）7 低。待用户圈定施工范围后按 H→M→L 推进；M-5 验证先行。
- 2026-08-13: 用户批准 P-008 → `D-006` 并施工完成（M-3 留待后续包）。(1) **H-1**：layouts.lua 四个布局函数（fresh/dual/review/focus）+ in-place 注入统一 `gate_spawn`——R1 强路径与「已解析 agent CLI 存在」双门禁先于一切 spawn，修复 fresh 先 spawn 后检查的孤儿页签与 review 的 nil-root gsub 崩溃。(2) **H-2**：sidebar `Write-DeskRootToFile` 自身成为 R5 硬门禁（拒绝保留名/弱路径，静默返回 $false），`b` 键调用前预检并红字提示；启动路径不再可能写入 home→home。(3) **H-3**：desk.lua `write_map`、sidebar `Write-DeskRootToFile`、bootstrap `Write-DeskRoots` 三处统一为 D-005 显式第三列（含 grok），重写时顺带丢弃既有弱/保留行（与 lua 语义对齐）。(4) **M-1**：launch.lua 新增 `find_agent_exe`（固定候选→PATH 扫描）+ `M.resolve_agent_exe`/`M.has_agent`（事件期惰性+记忆化）；resume.lua `continue_current`、projects.lua `open_as_workbench` 同步改为 has_agent 门禁；dual 的对照 agent 也须真实存在。(5) **M-2**：desk.lua `read_map`/`read_agent_map` 合并为单次解析 + 2s TTL 缓存（HUD 500ms tick 的高频读收敛为约 1 次/秒）；写路径（set_root/write_map）强制 fresh 解析，缓存不会丢并发写入。(6) **M-4** 随 M-1 落地：PATH 扫描跳过 `\\` UNC 与空项。(7) **M-5 实测**：PS 5.1 下 `Register-ObjectEvent -Action` 内写 `$global:` 主循环可见（prototypes/hardening-smoke/test-fsevent-global.ps1，3s 内触发）→ 自动刷新机制活着，无需修。(8) **L 批清**：L-1 全文键位对齐 F1/F3–F7 现状（help.lua/projects.lua/sidebar.ps1/Install-WZ.ps1 的 F8/F9/Alt+z 教学全部清除）；L-2 PS 弱路径/保留名表对齐 desk.lua（补 OneDrive、`.kimi`/`.kimi-code`/`.codex` 及 bin/sessions、AppData 本体、system32/temp、畸形 `\C:`）；L-3 三个写出方全部 temp+move 原子写；L-4 validate_project.ps1 新增 BOM 断言——**立即抓到 4 个存量漏网**（cheatsheet.txt、profile-snippet.ps1、Install-WZ.ps1、open-project.ps1 无 BOM 含 CJK），已补 BOM；L-5 ENVIRONMENT.md Verify 填入 validate + load guard；L-6 Init `d` 键 grok 缺席时禁用并提示；L-7 SCAN_ROOTS 移除 `~\.config`；另清 projects.lua 硬编码 `WZ_Skill` 修复兜底（F-009）。验证：门禁冒烟 14/14 PASS（提取 live sidebar 真实函数跑 temp RootsFile）；bootstrap/sidebar/profile-snippet/Install-WZ/open-project PS parse 全 0 错误（BOM 已重挂）；10 个 lua 模块块配平 OK；wezterm_load_guard OK；live↔镜像 16 对 md5 全一致；validate_project + readiness_check --verified OK。交互冒烟待用户（未绑定页签按 F6 应只弹 toast）。
- 2026-08-13: 用户正式退役 Leader → `D-007`；新增 `F-013`（现行键位事实：无 Leader、F1/F3–F7、Init 同屏两步）并 **supersede F-004**（F9/F8/Leader Alt+z 旧模型，WS/DESK 任务模型由 F-013 继承）。docs/MAIN.md 同步：键位表重写、任务模型表 agent 平权化、F-003 原则补 F1/F5 有意识例外注记、UX 表/残留痛点/封装验收中的 F9/F8/Leader-t/Ctrl+Alt+T/Ctrl+F5 死链清除、§Multi-model §5 两步流描述更新为定稿的同屏两区两步。**验收清单（P-006 草案）按现行设计整体重写**：B 区 F9/F8/Leader 三项替换为 F1 速查/Init 两步流/无 Leader 不抢 agent；A2/A3 平权化并纳入 D-006 新门禁行为；C3 纯 shell 逃生改为 Init `s`；D 区补 M-3 残留。live 配置无需改动（keys.lua 早已 `leader = nil`）。待用户批准修订后清单（→ D）再逐项 live 打勾。

## Next ID Hints

- Method: `M-004`
- Fact: `F-015`
- Decision: `D-017`

These hints are conveniences, not authority. Search before allocating an ID.
