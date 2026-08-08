# Current Context

## Workset Manifest

- Methods: M-001, M-002, M-003
- Facts: F-001, F-002, F-003, F-004, F-005, F-006
- Decisions: D-001, D-002
- Sources: none
- Assets: none
- Components: C-ROOT, C-WB, C-REF-WEZ, C-SKILL, C-LAUNCH
- Read: PROJECT_STATE.md,CONTEXT.md,DECISIONS.md,docs/MAIN.md,docs/refs/wezterm-local.md
- Write: PROJECT_STATE.md,CONTEXT.md,DECISIONS.md,docs/MAIN.md,PROJECT_MAP.md
- Verify: powershell -ExecutionPolicy Bypass -File scripts/validate_project.ps1
- Excluded: none
- Coverage: CONTEXT.md

## Current Package

- ID: PKG-001
- Goal: Lock name WZ-AiWorkBench + workbench-first phase; demote skill packaging from critical path.
- Output anchor: `docs/MAIN.md`
- Allowed change: Docs, approved D-*, maps; placeholder skill demotion only.
- Forbidden change: PPS product import; new D-* without OK; shipping skill as current deliverable.

## Pending Feedback

- Concrete workbench “done” checklist (gaps vs current AI STAR CUBE).
- Next edits only under live `~\.config\wezterm` vs also version modules in-repo.

## Proposals

- P-004: PKG-002 = workbench gaps only; patch live config; session-verify F6–F9 / tabs / WS-DESK.
- P-005: Keep `skills/wz-skill/` frozen placeholder until packaging; restructure under WZ-AiWorkBench then.
- P-003: Optional portable `assets/` still post-workbench.

## Working Assumptions

- H-002: PPS toolset at `G:\GrokProject\PPS_SKILL`; project `scripts/` for lifecycle.
- H-003: Live implementation stays external at `~\.config\wezterm` until a later D brings modules into git.

## Current Risks

- Wrong session cwd until `--cwd` / `open-project.ps1`.
- Live config vs docs drift.
- No explicit acceptance list → workbench phase cannot close.

## Constraint Coverage

| ID | Constraint | Artifact / section | Result |
|---|---|---|---|
| M-001 | Stable IDs + workset | `CONTEXT.md` Manifest | Present |
| M-002 | Close after verify | `AGENTS.md` | Present |
| M-003 | PPS process-only | `docs/MAIN.md` | Present |
| F-001 | AI workbench product | `docs/MAIN.md` | Present |
| F-002 | Live config external | `docs/refs/wezterm-local.md` | Present |
| F-003 | Key principles | `docs/MAIN.md` principles | Present |
| F-004 | WS/DESK + F6–F9 | `docs/MAIN.md` key map | Present |
| F-005 | Session `--cwd` | `open-project.ps1` | Present |
| F-006 | Explorer↔AI same DESK + click open | live `desk.lua` / `sidebar.ps1` | Present |
| D-001 | Name WZ-AiWorkBench | `docs/MAIN.md` Naming | Present |
| D-002 | Workbench-first | `docs/MAIN.md` Phase policy | Present |

## Next Action

User smoke-test: focus Grok → F7 → DESK must match chat top bar; click a file opens default app. Collect next workbench gaps.
