# Project Map

This is a compact navigation map, not a generated inventory. Keep stable architecture boundaries here and keep file-level work in `CONTEXT.md`.

## Project Shape

- Mode: software
- Root truth: `docs/MAIN.md`
- Scale policy: retrieve the current package, component rows, and exact target paths before reading implementation content.
- Process protocol: PPS/1.1 via project-local `scripts/` (toolset source optional at `G:\GrokProject\PPS_SKILL`).

## Components

| ID | Root | Responsibility | Interfaces | Verification anchor |
|---|---|---|---|---|
| C-ROOT | . | Product project state, docs, and packaging | PPS hot state + README entry | `scripts/validate_project.ps1` |
| C-SKILL | skills/wz-skill | Distributable Agent skill for WezTerm / AI STAR CUBE | `SKILL.md` frontmatter + body for Grok/Codex | skill present + description triggers |
| C-REF-WEZ | docs/refs | Pointers to live WezTerm config (external tree; not product source) | path notes for `%USERPROFILE%\.config\wezterm` | user session smoke (F6–F9, F8) |

## Navigation Rules

- Add one stable `C-*` row per architecture boundary, not per file.
- Keep IDs stable when files move; update the Root column.
- Put current file/symbol targets in `CONTEXT.md`, not here.
- Do not paste source code, generated trees, dependency listings, or Git history into this map.
- Never treat `G:\GrokProject\PPS_SKILL` as a component of this product.
