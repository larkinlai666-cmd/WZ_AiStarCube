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

- Summary: Task model uses WS (workspace name) and DESK (task root path); F9 selects/enters task; F6 opens 3-pane AI desk on DESK; F7 opens Explorer on DESK; F8 toggles cheatsheet; Leader is Alt+; then lowercase.
- Source: `~/.config/wezterm/README.md` and cheatsheet after morning iteration.
- Scope: Skill interaction contract.
- Supersedes: early morning experimental F2/F3 explorer/project bindings.
- Affects: skill key tables, agent guidance.

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

## Status Events

- 2026-08-07: Initialized `M-001` and `M-002` as active project method constraints.
- 2026-08-07: Separated product root from PPS clone; added `M-003`, `F-001`–`F-005` from recovered morning work and user protocol clarification.
- 2026-08-07: User approved `D-001` (name WZ-AiWorkBench) and `D-002` (workbench-first; skill packaging deferred).
- 2026-08-07: Added `F-006` — Explorer/AI task-root sync + clickable default-open in sidebar.

## Next ID Hints

- Method: `M-004`
- Fact: `F-007`
- Decision: `D-003`

These hints are conveniences, not authority. Search before allocating an ID.
