# Progress Snapshot — 2026-08-09

公开仓库 **WZ_AiStarCube** 同步点。用量收口前，把「开发到现在的明确信息」固化于此。

## 一句话

在 **WezTerm** 上把 AI Agent 终端交互做成 **AI STAR CUBE 工作台**：项目身份写死、页签多任务、Grok/Explorer 同根，再演进为 Skill/工作流。

## 问题 → 方案

| 痛点 | 方案（已实现） |
|------|----------------|
| 会话 cwd 与项目目录分离（home 开聊却写项目） | 门禁 R1–R6；强制 `--cwd`；Init 拒绝 SYS/home 正式开聊 |
| 项目名混乱（标题 / leaf / home） | 「项目名」= desk-roots 绑定名；`.wz-project` 加固 |
| 多项目靠切 Workspace 藏页签 | tabs-first：`prefer_to_spawn_tabs`；F9 新页签并排 |
| 无统一入口 | 冷启动/新标签 → Init 表；`c` 新建向导冻结路径 |
| 侧栏与对话不同根 | F7 解析页签 DESK / Grok `--cwd` |
| 裸 Start-Process 叠 OS 窗 | `open-project.ps1` / Init 用 `wezterm cli spawn` |

## 模块对照（live 快照）

| 文件 | 职责 |
|------|------|
| `desk.lua` | 强弱路径、name_for_path、set_root 门禁、页签 DESK |
| `bootstrap.ps1` | Init 列表 / DETAIL / 新建向导 / Start-GrokTab 门禁 |
| `projects.lua` | F9 / F7 |
| `status.lua` | 路径槽 + 页签 Project·Role |
| `layouts.lua` | F6 三栏 |
| `keys.lua` | 键位策略 |
| `sidebar.ps1` | Explorer |
| `open-project.ps1` | 仓外入口：spawn + 绑定 + marker |

## 权威 ID（节选）

- **D-001** 产品族名 WZ-AiWorkBench  
- **D-002** 工作台优先，Skill 后置  
- **D-003** 项目名/路径创建时写死  
- **F-004** F6–F9 / Leader 任务模型  
- **F-005** Grok cwd = 启动 cwd  
- **F-006** Explorer 与 AI 同根  
- **F-007** 门禁 R1–R6  
- **F-008** 新建向导冻结路径  

## 事故修复（2026-08-09）

- **现象**：重启 WezTerm → `attempt to yield across a C-call boundary` → 整份配置失败，界面像「出厂默认」（Init/F6–F9 全无）。
- **根因**：`launch.lua` 在 **config load / require** 时调用 `wezterm.run_child_process("where grok")`。
- **修复**：仅用 `io.open` + `PATH` 环境变量解析 `grok.exe`；**禁止**在加载期 spawn。
- **数据**：`desk-roots.tsv` / sessions / workbench 模块均未丢失，只是加载失败导致未生效。
- **防回归**：见 `docs/CONFIG_LOAD_SAFETY.md` + `scripts/wezterm_load_guard.ps1`；`wezterm.lua` soft-require。

## 三方对照（本机 live / 仓工作区 / GitHub origin）

分析命令：`scripts/wezterm_load_guard.ps1` + hash 对比 live ↔ `live-workbench/`。

| | 本机 `~/.config/wezterm` | 仓 `live-workbench/` 工作区 | GitHub `origin/main` |
|--|--------------------------|----------------------------|----------------------|
| 主 Lua 模块 hash | 与左栏一致（已对齐） | 与本机一致 | **落后**：仍含加载期 `where.exe` |
| 启动 yield 炸弹 | 已消除 | 已消除（未提交则 push 前无效） | **仍存在** → 第三方 Install 会炸 |
| 门禁 R1–R6 / Init | 有 | 有 | 有（同 HEAD 快照） |
| 个人 desk-roots | 真实路径 | 仅 example | 仅 example |
| 路径槽策略 | 动态全量 + Peach 色（STATUS_GEN） | 同左 | 同已提交快照 |

**对抗性结论：** 「本机能用」≠「线上安全」。公开仓在修复 **commit + push** 前，任何 `git clone` + `Install-WZ.ps1` 都会装回事故版。

## 明确未完成

- [ ] 作者「工作台达标」验收清单全过  
- [ ] 真正可分发的 Skill 正文（`skills/` 仍为占位）  
- [ ] 跨机安装/同步产品化（目前手工 copy live-workbench）  
- [ ] 历史 home-cwd 会话清理策略（仅隐藏，未删除）  

## 本机 vs 公开仓

| | 本机 | 公开仓 |
|--|------|--------|
| 运行配置 | `~/.config/wezterm/` | `live-workbench/` 快照 |
| 个人 desk-roots | 真实项目路径 | **仅 example** |
| 会话 transcript | `~/.grok/sessions` | **不上传** |

## 下一动作（用量恢复后）

1. 重载 WezTerm，验收 Init / 门禁 / 路径槽  
2. 补验收清单  
3. 封装阶段再开 Skill 包  
