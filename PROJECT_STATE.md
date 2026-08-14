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
- Next: User: wezterm 完全重开后 live 终验 P-011 施工（① 启动菜单只剩 Init/grok dash/PS/CMD 四入口；② 超长数字手滑得「number too long」提示不脏屏）→ F6 三栏形态定夺 → 批准验收清单（P-006 → D）→ 逐项打勾 A1–C4.
- Updated: 2026-08-14T15:56:00Z
- Device: SK-20240507HWFH

## Objective

Build **WZ-AiWorkBench**: a personal AI workbench product centered on WezTerm / **AI STAR CUBE**, strong enough for daily agent workflows (Grok, Codex, etc.). **First** finish the live workbench to the author’s satisfaction; **then** encapsulate behavior as one or more skills and related engineering modules under the WZ-AiWorkBench name.

This repository is the **WZ-AiWorkBench product project**. It is **not** a fork of PPS. PPS is only the external working protocol (bounded resume, authority IDs, worksets, close gates).

## Scope

- In scope (current phase · D-002):
  - Iterate live workbench under `%USERPROFILE%\.config\wezterm\` (and project helpers like `open-project.ps1`).
  - Keep requirements, decisions, and behavior contracts in this repo (`docs/MAIN.md`, authority, refs).
  - Record residual gaps until the author accepts the workbench.
- In scope (later packaging phase):
  - Author distributable skill(s) / modules under the **WZ-AiWorkBench** family.
  - Optional portable defaults, install/sync logic.
- Out of scope:
  - Replacing or vendoring the PPS protocol product (`G:\GrokProject\PPS_SKILL`).
  - Building a multi-user team orchestration platform.
  - Treating skill packaging as the critical path before workbench acceptance.

## Milestones

- [x] Separate product root from PPS toolset clone.
- [x] Bootstrap this repo with PPS process files only.
- [x] Capture morning WZ requirements into authority + main doc.
- [x] Approve product family name **WZ-AiWorkBench** and workbench-first policy.
- [x] Draft workbench acceptance checklist (MAIN; pending user D).
- [x] Align Leader contract to Alt+z (F-004 + live docs/snapshot).
- [ ] Author approves checklist + live session smoke A1–C4.
- [ ] Author accepts workbench (“done enough”) against checklist.
- [ ] (Later) Ship WZ-AiWorkBench skill family + references.
- [ ] (Later) L3 audit and freeze v0.1 bundle.

## Resume Note

Start with `scripts/resume_packet.*`, then follow only the exact authority, component, asset IDs, and paths in `CONTEXT.md`. Git history and required asset materialization are separate readiness states. Process skill source (if needed): `G:\GrokProject\PPS_SKILL\skills\pps-skill` — do not merge its product goals into this project. Current critical path is **workbench UX**, not skill authoring.
