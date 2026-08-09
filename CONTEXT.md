# Current Context

## Workset Manifest

- Methods: M-001, M-002, M-003
- Facts: F-001, F-002, F-003, F-004, F-005, F-006, F-007, F-008
- Decisions: D-001, D-002, D-003
- Sources: none
- Assets: none
- Components: C-ROOT, C-WB, C-REF-WEZ, C-SKILL, C-LAUNCH
- Read: PROJECT_STATE.md,CONTEXT.md,DECISIONS.md,docs/MAIN.md,docs/refs/wezterm-local.md
- Write: PROJECT_STATE.md,CONTEXT.md,DECISIONS.md,docs/MAIN.md
- Verify: powershell -ExecutionPolicy Bypass -File scripts/validate_project.ps1
- Excluded: none
- Coverage: CONTEXT.md

## Current Package

- ID: PKG-001
- Goal: Gates + project-name freeze (D-003/F-007/F-008); keep workbench-first; skill packaging deferred.
- Output anchor: `docs/MAIN.md` + live `~\.config\wezterm\workbench\*`
- Allowed change: Live workbench gates/create-flow; docs/authority; open-project.ps1.
- Forbidden change: PPS product import; shipping skill as current deliverable.

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

- Historical home-cwd sessions remain on disk (hidden unless Init `a`); do not resume as formal TASK.
- Live config vs docs drift if gates change only on one side.
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
| F-007 | Hard gates R1–R6 + project name def | live `desk.lua` / `bootstrap.ps1` | Present |
| F-008 | Create flow freezes path | Init wizard `c` + `.wz-project` | Present |
| D-001 | Name WZ-AiWorkBench | `docs/MAIN.md` Naming | Present |
| D-002 | Workbench-first | `docs/MAIN.md` Phase policy | Present |
| D-003 | Project name/path freeze | `DECISIONS.md` + desk-roots | Present |

## Next Action

Reload WezTerm config; open Init: TASK list must not show home/Desktop; Enter on WZ_Skill uses `--cwd G:\GrokProject\WZ_Skill`; path slot matches. Optional: `c` wizard create a throwaway project under `G:\GrokProject`.
