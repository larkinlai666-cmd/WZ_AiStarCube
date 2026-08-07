# Project State

## Hot State

- Protocol: PPS/1.1
- Profile: standard
- Mode: software
- Stage: 1 / requirements-capture
- Main: docs/MAIN.md
- Map: PROJECT_MAP.md
- Environment: ENVIRONMENT.md
- Package: PKG-001
- Status: active
- Capsule: CONTEXT.md
- Coverage: CONTEXT.md
- Blockers: none
- Next: Draft `skills/wz-skill` (or final skill name) SKILL.md from recovered WezTerm/AI STAR CUBE requirements; keep PPS only as process discipline.
- Updated: 2026-08-07T04:40:00Z
- Device: SK-20240507HWFH

## Objective

Build a **general-purpose Agent Skill for WezTerm (wz)** that strongly improves AI-agent workflow interaction and productivity inside WezTerm—especially for tools without a desktop client (Grok, Codex, etc.). The skill encodes how agents should use the **AI STAR CUBE** workbench model (layouts, keys, WS/DESK task model, conflict rules) so sessions stay efficient and consistent across machines.

This repository is the **WZ product project**. It is **not** a fork of PPS. PPS is only the external working protocol (bounded resume, authority IDs, worksets, close gates).

## Scope

- In scope:
  - Recover and freeze morning WezTerm / AI STAR CUBE requirements as project facts and decisions.
  - Author distributable skill(s) under `skills/` for Grok/Codex-style agents.
  - Document how the skill maps to local WezTerm config (`~/.config/wezterm`) without owning that config tree as product source.
  - Use PPS scripts only for project state lifecycle (resume / validate / close).
- Out of scope:
  - Replacing or vendoring the PPS protocol product (`G:\GrokProject\PPS_SKILL`).
  - Building a multi-user team orchestration platform.
  - Turning this repo into a second copy of the PPS skill source tree.

## Milestones

- [x] Separate product root from PPS toolset clone.
- [x] Bootstrap this repo with PPS process files only.
- [x] Capture morning WZ requirements into authority + main doc.
- [ ] Approve skill name and first package scope.
- [ ] Ship first reviewable `SKILL.md` + references.
- [ ] Validate skill against real WezTerm session flows (F6/F7/F8/F9, Leader, WS/DESK).
- [ ] L3 audit and freeze v0.1 skill bundle.

## Resume Note

Start with `scripts/resume_packet.*`, then follow only the exact authority, component, asset IDs, and paths in `CONTEXT.md`. Git history and required asset materialization are separate readiness states. Process skill source (if needed): `G:\GrokProject\PPS_SKILL\skills\pps-skill` — do not merge its product goals into this project.
