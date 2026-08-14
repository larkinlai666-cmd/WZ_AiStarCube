# Current Context

## Workset Manifest

- Methods: M-001, M-002, M-003
- Facts: F-001, F-002, F-003, F-005, F-006, F-007, F-008, F-009, F-010, F-011, F-012, F-013, F-014
- Decisions: D-001, D-002, D-003, D-004, D-005, D-006, D-007, D-008, D-009, D-010, D-011, D-012, D-013, D-014
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

- 批准/修订 MAIN 验收清单（P-006，已按现行设计重写）→ 升格 D 后逐项 live 打勾（含 A1–C4 冒烟：新标签 Init 两步流、未绑定页签 F6 只弹 toast）.

## Proposals

- P-006: MAIN acceptance checklist — user approve as D.
- P-004/P-005: PKG-002 residual UX after checklist; freeze `skills/wz-skill/` until packaging.
- P-011: 加固审查 R2 — 已施工全量并回归绿（M2-1~6 + L2-1/2/3/5/7/9；L2-4/6/8 留观察），待用户 live 终验.

## Working Assumptions

- H-002: PPS at `G:\GrokProject\PPS_SKILL`; project `scripts/` lifecycle. H-003: Live `~\.config\wezterm`; keep `live-workbench/` in sync.
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
| F-013 | MAIN key map + `keys.lua`（无 Leader）+ DECISIONS F-013 | Present |
| F-014 | MAIN §2 deepseek 行 + live `bootstrap.ps1`/`launch.lua` deepseek 路由 + DECISIONS F-014 | Present |
| F-005 | `open-project.ps1` | Present |
| F-006 | live desk/sidebar | Present |
| F-007 | live desk/bootstrap | Present |
| F-008 | Init wizard `c` | Present |
| F-009 | Install-WZ + PORTABILITY | Present |
| F-010 | `docs/MAIN.md` §「Multi-model handover」+ DECISIONS F-010 | Present |
| F-011 | `docs/MAIN.md` §「Multi-model handover」§2 agent 注册表 | Present |
| F-012 | `docs/MAIN.md` §2 codex 行 + DECISIONS F-012 | Present |
| D-001 | MAIN Naming | Present |
| D-002 | MAIN Phase policy | Present |
| D-003 | DECISIONS + desk-roots | Present |
| D-004 | MAIN §Multi-model handover + DECISIONS D-004 | Present |
| D-005 | MAIN §Multi-model handover §5 缺省解析 + DECISIONS D-005 | Present |
| D-006 | `docs/compat-hardening-review.md` + live gates/写出方 + DECISIONS D-006 | Present |
| D-007 | MAIN key map「无 Leader 层」+ `keys.lua` `leader = nil` + DECISIONS D-007 | Present |
| D-008 | MAIN key map F6 行 + live `layouts.lua` pick_agent + DECISIONS D-008 | Present |
| D-009 | MAIN key map 新页签行 + §Multi-model §5 + 清单 B4 + live `bootstrap.ps1` 静态屏行输入 | Present |
| D-010 | MAIN §5 + 清单 B4 + live `bootstrap.ps1` 组合解析/9 行封顶 | Present |
| D-011 | live `bootstrap.ps1` `Set-SpawnedTabTitle` 严格解析/日志 + DECISIONS D-011 | Present |
| D-012 | live `bootstrap.ps1` Complete-AgentPick 成功即关 + `status.lua` argv 钉住 + cheatsheet | Present |
| D-013 | live `bootstrap.ps1` Write-UiChoice/Write-BoxKeyRow 结构强制 + `sidebar.ps1` 配色归位 + DECISIONS D-013 | Present |
| D-014 | live `options.lua` 单击开链接绑定 + `sidebar.ps1` launcher 护栏 + DECISIONS D-014 | Present |

## Next Action

P-011 已施工并推送（b488faa）；D-014 单击开链接恢复 + launcher 护栏已落地并推送。User: wezterm 完全重开后终验——① 侧栏单击文件名/目录名直接打开（.cmd/.exe 行为纯文本，用 `o N` 键盘开）；② 拖拽选择文字不受影响；③ 启动菜单四入口。随后 F6 三栏形态定夺（A/B/C）→ 批准验收清单（P-006 → D）→ 逐项打勾。M-3 留后续包。
