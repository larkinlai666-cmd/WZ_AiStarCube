# Current Context

## Workset Manifest

- Methods: M-001, M-002, M-003
- Facts: F-001, F-002, F-003, F-004, F-005, F-006, F-007, F-008, F-009
- Decisions: D-001, D-002, D-003
- Sources: none
- Assets: none
- Components: C-ROOT, C-WB, C-REF-WEZ, C-SKILL, C-LAUNCH
- Read: PROJECT_STATE.md,CONTEXT.md,DECISIONS.md,docs/MAIN.md,docs/refs/wezterm-local.md
- Write: PROJECT_STATE.md,CONTEXT.md,DECISIONS.md,docs/MAIN.md,README.md,live-workbench
- Verify: powershell -ExecutionPolicy Bypass -File scripts/validate_project.ps1
- Excluded: none
- Coverage: CONTEXT.md

## Current Package

- ID: PKG-001
- Goal: Acceptance checklist ready; Leader Alt+z aligned; skill deferred.
- Output anchor: `docs/MAIN.md` + live `~\.config\wezterm\workbench\*`
- Allowed change: Live UX/docs sync; authority; open-project; installer docs.
- Forbidden change: PPS product import; shipping skill now.

## Pending Feedback

- Approve/edit MAIN acceptance checklist (draft → D).
- Live smoke A1–C4 after `Ctrl+F5`.

## Proposals

- P-006: MAIN acceptance checklist — user approve as D.
- P-004: PKG-002 residual UX after checklist.
- P-005: Freeze `skills/wz-skill/` until packaging.

## Working Assumptions

- H-002: PPS at `G:\GrokProject\PPS_SKILL`; project `scripts/` lifecycle.
- H-003: Live `~\.config\wezterm`; keep `live-workbench/` in sync.

## Current Risks

- Home-cwd history not formal TASK.
- Unapproved checklist blocks workbench close.

## Constraint Coverage

| ID | Artifact / section | Result |
|---|---|---|
| M-001 | `CONTEXT.md` Manifest | Present |
| M-002 | `AGENTS.md` | Present |
| M-003 | `docs/MAIN.md` | Present |
| F-001 | `docs/MAIN.md` | Present |
| F-002 | `docs/refs/wezterm-local.md` | Present |
| F-003 | `docs/MAIN.md` principles | Present |
| F-004 | MAIN key map + `keys.lua` Alt+z | Present |
| F-005 | `open-project.ps1` | Present |
| F-006 | live desk/sidebar | Present |
| F-007 | live desk/bootstrap | Present |
| F-008 | Init wizard `c` | Present |
| F-009 | Install-WZ + PORTABILITY | Present |
| D-001 | MAIN Naming | Present |
| D-002 | MAIN Phase policy | Present |
| D-003 | DECISIONS + desk-roots | Present |

## Next Action

User approve MAIN checklist (「清单定了」) → live smoke A1–C4. Packaging deferred (D-002).
