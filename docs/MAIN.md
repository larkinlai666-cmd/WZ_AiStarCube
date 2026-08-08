# WZ-AiWorkBench — Main Artifact

## Product one-liner

**WZ-AiWorkBench**：以 WezTerm 为壳的 **AI STAR CUBE 个人 AI 工作台** 产品线。先把本机工作台做到彻底合用，再封装为可复用的 Agent Skill / 多 skill 与其它工程逻辑（名称统一归属 **WZ-AiWorkBench**）。

## Relation to PPS（重要）

| | PPS | WZ_Skill 仓库（本项目） |
|---|---|---|
| 是什么 | 个人项目状态协议 + 脚本工具集 | **WZ-AiWorkBench** 产品工程 |
| 内容是否重叠 | 无关（状态/恢复/权威 ID） | 无关（终端交互、布局、键位、任务区） |
| 本仓如何使用 | **只引用工作逻辑**：resume packet、M/F/D、Workset、收口门禁 | 被 PPS 脚本维护状态；阶段产物先是工作台能力，后是 skill 族 |
| 源码位置 | `G:\GrokProject\PPS_SKILL`（独立仓） | `G:\GrokProject\WZ_Skill` |

不要把 PPS 的 README/技能正文拷进本仓当产品功能。

## Phase policy（D-002）

| 阶段 | 焦点 | 状态 |
|---|---|---|
| **1 · 工作台本体** | 把 live WezTerm / AI STAR CUBE 做到个人满意 | **当前** |
| **2 · 封装** | 在需求已满足后，再做 WZ-AiWorkBench skill（可能多个）与其它工程逻辑 | 延后，未开包 |

当前 **不** 以「写出可分发 SKILL.md」为成功标准；`skills/` 下若有占位文件，仅作将来封装预留，不抢工作台迭代优先级。

## Naming（D-001）

- 产品 / 工作流族名：**WZ-AiWorkBench**
- 工作台对外称呼可继续用 **AI STAR CUBE**（体验品牌）
- 最终形态允许：**多个 skill**、启动/同步脚本、配置资产、其它模块 —— 不锁死成单一 skill
- 历史占位路径 `skills/wz-skill/` **不是** 产品定名；封装阶段再按 WZ-AiWorkBench 重组

## Problem

无桌面客户端的 AI CLI 默认只有「单终端聊天」。用户已在 WezTerm 上搭出 **AI STAR CUBE** 工作台（侧栏、三栏桌、项目切换、速查面板），但还需要：

1. 交互与任务模型稳定、符合个人习惯（键位、页签、WS/DESK、冲突规则）；
2. 顶栏 / cwd / 真项目路径对齐；
3. 把「本机已调通」的体验收成可恢复、可迭代的工程，而不是一次性配置碎片；
4. **全部满意之后**，再做成 Agent 可加载的 **WZ-AiWorkBench** 协议/skill 族。

## Target users

- 首要：作者本人（本机 WezTerm 工作台）
- 其次（封装阶段）：以 WezTerm 为 AI 主壳、并行 Grok/Codex 的个人用户

## Live workbench (implementation truth today)

Source of runtime behavior: `%USERPROFILE%\.config\wezterm\`（**不在本 git 树内**，F-002）。

```
%USERPROFILE%\.config\wezterm\
  wezterm.lua
  README.md
  workbench\  (keys, status, projects, desk, sidebar, help, cheatsheet, …)
```

本仓职责（工作台阶段）：

- 需求 / 决策 / 验收标准（本文件 + `DECISIONS.md`）
- 与工作台配套的仓内工具（如 `open-project.ps1`）
- 路径与行为说明（`docs/refs/`）
- 不以「拷贝整棵 config 进 git」为默认前提；是否资产化由后续 `D-*` 决定

### Design principles (binding · F-003)

1. 核心快捷键 **不要求大写 / Shift**（中文输入常态小写）。
2. 避免把 `Ctrl+Shift+字母`、滥用 `Ctrl+Alt+*` 当地板油。
3. 直达操作用 **F 键**，并避开 `F1 / F2 / F5 / F10 / F12`。
4. 能鼠标完成的不绑键（例如切窗格）。
5. **不与 Grok 抢** `F2`、`Ctrl+;`。
6. 绑定仅在 **WezTerm 窗口聚焦** 时生效（非系统全局热键）。

### Task model (F-004)

| Concept | Status bar | Meaning |
|---|---|---|
| **WS** | `WS:name` | Task workspace |
| **DESK** | `DESK:folder` | Task root directory (default cwd for Grok/F6) |
| Align / drift | green / orange | Whether pane cwd is under DESK |

Binding table on machine: `workbench\desk-roots.tsv`.

### Core key map (current local truth · F-004)

| Key | Action |
|---|---|
| F7 | Left Explorer (bound to DESK) |
| F9 | Project / task picker（当前窗 **新页签**，不藏旧页签） |
| F6 | Standard 3-pane AI desk |
| F8 | Cheatsheet panel toggle |
| F4 | Close pane |
| F11 | Fullscreen |
| Leader `Alt+;` then lowercase | `h` help · `e` explorer · `.` pick project · `j` jump open tasks · `a`/`b` 3-pane · … |

Deliberately unbound: F1, F2, F5, F10, F12; `Ctrl+;` reserved for Grok prompt queue.

### Session cwd (F-005)

Grok 顶栏 cwd = 进程启动 cwd；会话内 `cd` 不改顶栏。应用 `--cwd` 或 `open-project.ps1`（优先 `wezterm cli spawn` / `--new-tab`，禁止裸 `Start-Process grok` 叠 OS 窗）。

### Workbench UX fixed / in progress

| 项 | 状态 | 说明 |
|---|---|---|
| F-006 侧栏与对话同根 | **已改 live config** | 焦点在 Grok 时 F7 以 `--cwd` 为 DESK；页签级 desk；`open-project.ps1` 写 desk-roots |
| F-006 侧栏可点击打开 | **已改** | 文件 OSC-8；文件夹数字进入；0 上级 |
| 顶栏本页签动态任务 | **已改** | 状态跟 **当前标签** 窗格 cwd；关 HUD：`Alt+z` 再 `Shift+H` |
| 任务初始化面板 | **冷启动+新标签统一** | `default_prog`/Ctrl+Shift+T/Leader-t → `bootstrap.ps1` 表格；纯 Shell=Ctrl+Alt+T；分屏仍 PS；`no-bootstrap` 可关 |

### Known residual pain (workbench backlog seeds)

- 已打开的旧 Explorer 窗格不会自动跟新对话；需 F4 关掉后 **先点 Grok 再 F7**。
- F9 / Leader 依赖聚焦、英文 `;`、笔记本 `Fn`。
- 个人「彻底想要的样子」其余缺口待继续收集。
- 配置在 home 树，跨机/备份策略未定。

## Current package target (workbench-first)

**PKG-001（重定向）**：冻结命名与阶段策略；把主线从「先写 skill」改为「先迭代工作台」。

下一步工程包应围绕：

1. 用户明确的工作台缺口（布局 / 键 / 任务流 / 视觉 / 启动 / 侧栏 …）
2. 在 live config 上改 → 真机会话验证
3. 回写本仓 MAIN / 权威 / 可选 refs（行为契约）

**不在当前主线：** 完整 `SKILL.md` 正文、多 skill 打包、对外分发。

## Deferred: skill encapsulation (post workbench)

当用户宣布工作台达标后，再开封装包，预期包括：

1. 以 **WZ-AiWorkBench** 为族名的 skill（可能多个）
2. Agent 对 WS/DESK、键位作用域、Grok 共存、cwd 纪律的可执行协议
3. 可选：portable assets / 安装与同步逻辑
4. 验收：在真实 WezTerm 流上对照 F6–F9 / Leader / 启动脚本

## Acceptance (phase-split)

### Workbench phase (current)

- [x] 产品族名定为 WZ-AiWorkBench（D-001）
- [x] 明确 skill 封装后置（D-002）
- [ ] 用户给出或批准「工作台达标」验收清单
- [ ] 清单项在 live 会话中全部通过
- [ ] 行为契约与本仓文档一致（无关键漂移）

### Packaging phase (later)

- [ ] WZ-AiWorkBench skill 族命名与目录落盘
- [ ] `SKILL.md`（及可能的姊妹 skill）可被 Agent 正确触发
- [ ] 原则 + 键位 + 任务模型 + 启动纪律写入 skill
- [ ] 真机流程验证 + L3 冻结 v0.1
