# WZ Skill — Main Artifact

## Product one-liner

**WZ Skill**：面向 WezTerm 的通用 Agent Skill，把「AI STAR CUBE 工作台」的交互模型、快捷键纪律、任务区（WS/DESK）关系固化成 Agent 可执行协议，显著提升 Grok / Codex 等无桌面客户端 AI 在终端里的协作效率。

## Relation to PPS（重要）

| | PPS | WZ_Skill（本仓库） |
|---|---|---|
| 是什么 | 个人项目状态协议 + 脚本工具集 | WezTerm/AI 工作台的 **产品 Skill** |
| 内容是否重叠 | 无关（状态/恢复/权威 ID） | 无关（终端交互、布局、键位、任务区） |
| 本仓如何使用 | **只引用工作逻辑**：resume packet、M/F/D、Workset、收口门禁 | 被 PPS 脚本维护状态；产物是 `skills/*` |
| 源码位置 | `G:\GrokProject\PPS_SKILL`（独立仓） | `G:\GrokProject\WZ_Skill` |

不要把 PPS 的 README/技能正文拷进本仓当产品功能。

## Problem

无桌面客户端的 AI CLI 默认只有「单终端聊天」。用户已在 WezTerm 上搭出 **AI STAR CUBE** 工作台（侧栏、三栏桌、项目切换、速查面板），但：

1. 每次换 Agent / 换会话容易丢掉键位与任务区约定；
2. 顶部工作区 cwd 与真实项目路径容易脱节；
3. 快捷键与系统 / Grok TUI / 中文输入法冲突成本高；
4. 需要一份 **Agent 可自动加载** 的通用 skill，而不是只有本机 `~/.config/wezterm` 配置。

## Target users

- 以 WezTerm 为 AI 主交互壳的个人用户
- 并行使用 Grok Build、Codex 等 TUI/CLI 的开发者

## Recovered requirements (2026-08-07 morning)

Source: Grok sessions on WezTerm / AI STAR CUBE + live config under `%USERPROFILE%\.config\wezterm\`.

### Goals stated by user

1. 用 **wez** 作为 AI 工具的核心交互终端。
2. 大幅提升无桌面客户端 AI（如 Grok）的交互效率。
3. 目标是 **专业、桌面化的 AI 工作台**（已命名 **AI STAR CUBE**）。

### Design principles (binding intent)

1. 核心快捷键 **不要求大写 / Shift**（中文输入常态小写）。
2. 避免把 `Ctrl+Shift+字母`、滥用 `Ctrl+Alt+*` 当地板油。
3. 直达操作用 **F 键**，并避开 `F1 / F2 / F5 / F10 / F12`。
4. 能鼠标完成的不绑键（例如切窗格）。
5. **不与 Grok 抢** `F2`、`Ctrl+;`。
6. 绑定仅在 **WezTerm 窗口聚焦** 时生效（非系统全局热键）。

### Task model

| Concept | Status bar | Meaning |
|---|---|---|
| **WS** | `WS:name` | Task workspace (switch via F9) |
| **DESK** | `DESK:folder` | Task root directory (default cwd for Grok/F6) |
| Align / drift | green / orange | Whether pane cwd is under DESK |

Binding table on machine: `workbench\desk-roots.tsv`.

### Core key map (current local truth)

| Key | Action |
|---|---|
| F7 | Left Explorer (bound to DESK) |
| F9 | Project / task picker |
| F6 | Standard 3-pane AI desk |
| F8 | Cheatsheet panel toggle |
| F4 | Close pane |
| F11 | Fullscreen |
| Leader `Alt+;` then lowercase | `h` help · `e` explorer · `.` pick project · `j` jump open tasks · `a`/`b` 3-pane · … |

Deliberately unbound: F1, F2, F5, F10, F12; `Ctrl+;` reserved for Grok prompt queue.

### Local implementation assets (reference, not this repo)

```
%USERPROFILE%\.config\wezterm\
  wezterm.lua
  README.md
  workbench\  (keys, status, projects, desk, sidebar, help, cheatsheet, …)
```

### Pain points still skill-worthy

- Session workspace / TUI top path vs real project cwd mismatch.
- F9 / Leader depend on focus, English `;`, laptop `Fn`.
- Need updatable conflict audit + toggleable help (F8 exists).
- Productize as **portable skill**, not only local config patches.

## First deliverable (PKG-001 target)

A reviewable Agent skill package that:

1. Auto-invokes when user talks about WezTerm / wz / AI STAR CUBE / 工作台快捷键 / 任务区.
2. Instructs agents to respect WS/DESK, key scope, and Grok coexistence rules.
3. Points to config paths and recovery steps without dumping whole trees.
4. Does not embed PPS product content.

## Acceptance (draft)

- [ ] Skill name fixed and valid for Grok skill rules.
- [ ] `SKILL.md` description triggers correctly on wz / WezTerm / AI STAR CUBE intents.
- [ ] Principles + key map + task model covered with clear Agent steps.
- [ ] PPS validate_project clean after package close.
- [ ] Skill usable when this repo is the session `--cwd`.
