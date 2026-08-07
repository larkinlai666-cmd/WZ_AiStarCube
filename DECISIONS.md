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

## Status Events

- 2026-08-07: Initialized `M-001` and `M-002` as active project method constraints.
- 2026-08-07: Separated product root from PPS clone; added `M-003`, `F-001`–`F-005` from recovered morning work and user protocol clarification.

## Next ID Hints

- Method: `M-004`
- Fact: `F-006`
- Decision: `D-001`

These hints are conveniences, not authority. Search before allocating an ID.
