# Authority and Decisions

## Active Authority Index

<!-- PPS:ACTIVE:BEGIN -->
- `M-001`
- `M-002`
- `M-003`
- `F-001`
- `F-002`
- `F-003`
- `F-004`
- `F-005`
- `F-006`
- `D-001`
- `D-002`
- `D-003`
- `F-007`
- `F-008`
- `F-009`
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

### F-004 [active]

- Summary: Task model uses WS (workspace name) and DESK (task root path); F9 selects/enters task; F6 opens 3-pane AI desk on DESK; F7 opens Explorer on DESK; F8 toggles cheatsheet; Leader is **Alt+z** then lowercase (legacy Alt+; kept only for a few chords; primary docs must not teach Alt+; as Leader — CN IME often never enters LEADER).
- Source: `keys.lua` + live workbench 2026-08-09 (IME-safe Leader); morning iteration for F6–F9 model.
- Scope: Skill interaction contract.
- Supersedes: early morning experimental F2/F3 explorer/project bindings; teaching Leader as Alt+;.
- Affects: skill key tables, agent guidance, cheatsheet, MAIN key map.

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

## Status Events

- 2026-08-09: Corrected `F-004` Leader chord to **Alt+z** (was documented as Alt+;); aligns with live `keys.lua` and PORTABILITY audit.
- 2026-08-07: Initialized `M-001` and `M-002` as active project method constraints.
- 2026-08-07: Separated product root from PPS clone; added `M-003`, `F-001`–`F-005` from recovered morning work and user protocol clarification.
- 2026-08-07: User approved `D-001` (name WZ-AiWorkBench) and `D-002` (workbench-first; skill packaging deferred).
- 2026-08-07: Added `F-006` — Explorer/AI task-root sync + clickable default-open in sidebar.
- 2026-08-09: Added `D-003` / `F-007` / `F-008` — project name definition, hard gates, create-flow path freeze; purged home/Desktop from desk-roots.
- 2026-08-09: Added `F-009` — Install-WZ.ps1 portable third-party install; fixed hard-coded G: default parent.

## Next ID Hints

- Method: `M-004`
- Fact: `F-010`
- Decision: `D-004`

These hints are conveniences, not authority. Search before allocating an ID.
