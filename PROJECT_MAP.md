# Project Map

This is a compact navigation map, not a generated inventory. Keep stable architecture boundaries here and keep file-level work in `CONTEXT.md`.

## Project Shape

- Mode: software
- Product family: **WZ-AiWorkBench**
- Root truth: `docs/MAIN.md`
- Scale policy: retrieve the current package, component rows, and exact target paths before reading implementation content.
- Process protocol: PPS/1.1 via project-local `scripts/` (toolset source optional at `G:\GrokProject\PPS_SKILL`).
- Phase: workbench-first (D-002); skill packaging deferred.

## Components

| ID | Root | Responsibility | Interfaces | Verification anchor |
|---|---|---|---|---|
| C-ROOT | . | Product project state, docs, and packaging | PPS hot state + README entry | `scripts/validate_project.ps1` |
| C-WB | docs | Workbench behavior contract and phase goals for AI STAR CUBE / WZ-AiWorkBench; live code stays external | `docs/MAIN.md` workbench sections; runtime at `%USERPROFILE%\.config\wezterm` | User session smoke (F6–F9, F8, tabs, WS/DESK) |
| C-REF-WEZ | docs/refs | Pointers and behavior notes for the live tree | path notes for wezterm config | docs match live README/cheatsheet intent |
| C-SKILL | skills/wz-skill | Future WZ-AiWorkBench skill family (placeholder only this phase) | deferred until workbench accepted | N/A critical path this phase |
| C-LAUNCH | open-project.ps1 | Correct-cwd Grok launch into WezTerm tabs | `wezterm cli spawn` / `--new-tab` | Tab opens under project root, no stacked OS window |

## Navigation Rules

- Add one stable `C-*` row per architecture boundary, not per file.
- Keep IDs stable when files move; update the Root column.
- Put current file/symbol targets in `CONTEXT.md`, not here.
- Do not paste source code, generated trees, dependency listings, or Git history into this map.
- Never treat `G:\GrokProject\PPS_SKILL` as a component of this product.
- Live workbench implementation is **external** by default (H-003); do not bulk-import it without a decision. Component Root columns are always in-repo paths for PPS validation.
