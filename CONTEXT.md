# Current Context

## Workset Manifest

- Methods: M-001, M-002, M-003
- Facts: F-001, F-002, F-003, F-004, F-005
- Decisions: none
- Sources: none
- Assets: none
- Components: C-ROOT, C-SKILL, C-REF-WEZ
- Read: PROJECT_STATE.md,CONTEXT.md,DECISIONS.md,docs/MAIN.md,README.md,docs/refs/wezterm-local.md
- Write: PROJECT_STATE.md,CONTEXT.md,DECISIONS.md,docs/MAIN.md,skills/wz-skill/SKILL.md
- Verify: powershell -ExecutionPolicy Bypass -File scripts/validate_project.ps1
- Excluded: none
- Coverage: CONTEXT.md

## Current Package

- ID: PKG-001
- Goal: Freeze recovered WezTerm/AI STAR CUBE requirements; open first skill draft path.
- Output anchor: `docs/MAIN.md`
- Allowed change: Project docs, authority facts, skill scaffold, launch helper.
- Forbidden change: Importing PPS product tree; inventing `D-*` without user OK.

## Pending Feedback

- Skill final name (placeholder `wz-skill`).
- Docs-only skill first vs config install/patch automation.

## Proposals

- P-001: Name skill `wz-skill` (triggers: wez, wezterm, wz, AI STAR CUBE).
- P-002: Keep live WezTerm config outside this git repo; document paths only.
- P-003: Later optional portable defaults under `assets/`.

## Working Assumptions

- H-001: First package can ship documentation-grade skill instructions before installers.
- H-002: PPS toolset stays at `G:\GrokProject\PPS_SKILL`; project `scripts/` handle lifecycle.

## Current Risks

- Old Grok sessions may still show home cwd until reopened with `--cwd`.
- Local WezTerm config can drift from skill docs.

## Constraint Coverage

| ID | Constraint | Artifact / section | Result |
|---|---|---|---|
| M-001 | Stable IDs + explicit workset | `CONTEXT.md` / Manifest | Present |
| M-002 | Close after propagation + validation | `AGENTS.md` | Present |
| M-003 | PPS process-only; no product overlap | `docs/MAIN.md`, `README.md` | Present |
| F-001 | WZ skill for AI agent efficiency | `PROJECT_STATE.md`, `docs/MAIN.md` | Present |
| F-002 | Morning config is local reference | `docs/refs/wezterm-local.md` | Present |
| F-003 | Lowercase-first / conflict-aware keys | `docs/MAIN.md` / principles | Present |
| F-004 | WS/DESK + F6–F9 + Alt+; leader | `docs/MAIN.md` / key map | Present |
| F-005 | Session cwd via `--cwd` | `open-project.ps1` | Present |

## Next Action

Confirm skill name (or accept `wz-skill`), then author full `skills/wz-skill/SKILL.md` and close PKG-001.
