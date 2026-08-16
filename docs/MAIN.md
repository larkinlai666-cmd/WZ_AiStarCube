# WZ-AiWorkBench — Main Artifact

## Product one-liner

**WZ-AiWorkBench**：以 WezTerm 为壳的 **AI STAR CUBE 个人 AI 工作台** 产品线。公开仓库名为 **WZ_AiStarCube_win**，是纯 Windows 平台项目；macOS、Linux 与 WSL 宿主不在支持范围内。先把本机工作台做到彻底合用，再封装为可复用的 Agent Skill / 多 skill 与其它工程逻辑。

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
- 其次（封装阶段）：在 Windows 上以 WezTerm 为 AI 主壳、并行使用任意可发现 Agent CLI 的个人用户

## Live workbench (implementation truth today)

Source snapshot: 本仓 `live-workbench/`；installed runtime: `%USERPROFILE%\.config\wezterm\`。发布前两者必须通过哈希同步校验。

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
   - 有意识的例外（F-013）：`F1` = 速查面板（可能被 Windows 帮助吞，面板内 `q` 兜底）；`F5` = 重载（`Ctrl+Shift+R` 冗余应急）。
4. 能鼠标完成的不绑键（例如切窗格）。
5. **不与 Grok 抢** `F2`、`Ctrl+;`（kimi/codex 等同理——字母键整体留给 agent）。
6. 绑定仅在 **WezTerm 窗口聚焦** 时生效（非系统全局热键）。
7. **无 Leader 前缀层（D-007）**；非全局动作一律进 Init 面板本地键。

### Task model (F-013 + D-003)

| Concept | Where | Meaning |
|---|---|---|
| **项目名** | `desk-roots` 左列 / `.wz-project` `name=` | 绑定名（Init 列表/页签显示）；**不是** agent 会话标题 |
| **项目路径** | `desk-roots` 右列 / `.wz-project` `path=` | 写死的绝对路径；agent 必须以它为启动 cwd（grok `--cwd` / codex `-C` / kimi 进程 cwd） |
| **会话 cwd** | agent 顶栏 | 进程启动 cwd；会话内 `cd` 不改身份 |
| **路径槽** | Wez 左状态栏 | 当前页签 DESK（强路径） |

Binding table on machine: `workbench\desk-roots.tsv`. Marker: `<project>\.wz-project`.

**Gates (F-007):** home / Desktop / Documents 根 / Downloads / AppData / Temp 永不当正式项目；启动菜单不再提供 “Grok @ home”；Init 对 SYS 行拒绝 Enter 开聊。

### Multi-model handover（D-004）

背景（F-010）：既有设计以「Grok 单模型会话」为默认假设，未预留多个模型（Grok / Kimi / Codex / …）接手同一任务的机制。设计原则：**任务身份与模型解耦；同模型接手续会话，跨模型接手走文件态，绝不依赖会话历史**。

#### 1 · 任务 ≠ 会话

任务 = desk-roots 绑定（名 + 冻结路径），不属于任何模型/CLI。某模型的会话只是任务的一次运行时实例。任何 agent CLI 在冻结路径上启动即视为在该任务上工作。门禁 R1–R6 与模型无关，逐字保留。

#### 2 · Agent 开放探测与可选续聊适配器（D-016）

候选列表**不写死产品类型**。每次 Init 冷启动（或两步中的任一步按 `r`）由 `agent-discovery.ps1` 重新枚举，并合并宿主进程 PATH 与最新用户/系统持久化 PATH，因此安装器更新 PATH 后无需重启整个 WezTerm。自动证据包括 npm/Python 包元数据、可执行文件版本元数据、`*.wz-agent.json`；对于没有包清单/版本资源、安装在用户级专属 `app\bin` 的独立 EXE，则以受字节上限约束的静态能力词扫描识别，结果按路径+大小+修改时间缓存，相同负载别名折叠到与应用目录最匹配的主命令。探测过程从不执行候选程序，判断词只描述 AI/coding-agent 能力，不含产品名。仍完全静默的独立二进制可在本地 TSV 写 `id<TAB>label<TAB>command-or-absolute-path`（第三列支持 `|` 分隔别名），同样无需改源码。仓库自带 `agent-registry.tsv` 只有协议说明，不带产品白名单。

下表只记录已有的**续聊参数适配器**，不是发现清单；没有专属适配器的新 Agent 仍可等权展示并以项目 cwd 正常新开：

| Agent | 启动方式 | 同模型续接手 | 备注 |
|---|---|---|---|
| `grok` | `grok --cwd <path>`（F-005） | Grok 自有 resume | 现有一等行为，不动 |
| `kimi` | **无 `--cwd`**；由 `wezterm cli spawn --cwd <path> -- kimi` 设定进程 cwd 后启动（F-011） | `kimi --continue`（续当前目录最近会话；会话按工作目录分组存于 `~/.kimi-code/sessions/`） | 本设计的一等公民 |
| `codex` | `codex -C/--cd <path>`，或 spawn 设定进程 cwd（F-012） | `codex resume --last`（续最近）/ `codex resume <id>`（picker 按 cwd 过滤）；会话存 `~/.codex/sessions/` | WinGet `.cmd` 垫片须经 PowerShell host；续聊前比较运行时与 `session_meta.payload.cli_version`，旧读取器只提示升级、不 spawn 失败页签 |
| `deepseek` | **无 `--cwd`**；spawn 进程 cwd = 项目身份（kimi 同款，F-014） | `deepseek --continue`/`--resume`（续当前目录已存会话；存于 `~/.deepseek-cli/sessions/<sha256(cwd)[0:16]>.json`，REPL 进入时亦自动恢复） | 社区版 `@kavienw/deepseek-cli`（npm 全局，`.cmd` 垫片经 PowerShell host）；需 DeepSeek API Key，首启在页签内交互录入并自动保存 |

HUD/接管检测：按窗格前台进程名识别 agent（grok / kimi / codex / deepseek），识别不出视为普通 shell。

#### 3 · 交接契约（跨模型）

- **PPS 项目**：交接物 = 恢复包（`scripts/resume_packet.*` + `PROJECT_STATE.md` + `CONTEXT.md`）。本会话 Grok→Kimi 已实证此路径可用，不另造机制。
- **一般项目**：交接物 = `<项目根>\.wz-handoff.md`（workbench 所有，命名对齐 `.wz-project`）。模板：

```
# Handoff — <项目名>
- Updated: <ISO 时间>
- Last agent: <cli 名 + 模型>
- Goal: <当前目标一句话>
- Done: <已完成要点>
- Pending: <下一步，含入口文件/命令>
- Files: <本阶段实际改动的关键路径>
- Verify: <验证命令>
- Notes: <坑、约定、不要动的地方>
```

- 会话 transcript **显式排除**在交接物之外；同模型同机优先用各自 resume（如 `kimi --continue`），跨模型必须走上述文件。
- 写纪律：agent 在任务收口/中断前更新 `.wz-handoff.md`（或 PPS 项目走既有收口写集）。

#### 4 · 接手协议（incoming agent 固定动作）

1. 由 desk-roots / `.wz-project` 解析任务根（弱路径拒绝不变）；
2. 有恢复包走 L0；否则读 `.wz-handoff.md`（缺文件则按新任务处理）；
3. 只读交接物列出的文件/符号，再动手；
4. 先跑 `Verify` 确认基线，再改；
5. 不得假设能看到上一模型的对话内容。

#### 5 · 启动槽位泛化

- `open-project.ps1 -Agent <任意探测到的 route id>`；默认以 spawn 的项目 cwd 作为任务身份，产品专属 resume 仅由可选适配器追加。
- `desk-roots.tsv` 可选第三列 `agent`；新建向导选择 AI 时显式写入该动态 route id，读取方容忍两列旧行。
- **缺省解析（D-005，由 D-016 泛化）**：显式指定（第三列 / `-Agent` / 向导选择）> 当前开放探测结果第一项（稳定按 label/id 排序）；不存在任何产品优先级或未知类型回退。
- Init 新建向导 `c` 为四步：名称 → 位置 → **Agent / CLI 单一选择** → 确认。所选 AI CLI 同时写入 `desk-roots.tsv` 第三列，禁止再产生「启动 CLI 与默认 agent 不同」的组合；`PowerShell only` 使用明确的 `shell` route id，不得偷偷回退成 grok（D-015）。
- **启动与 agent 解耦（核心理念，2026-08-13 定稿；D-009 行输入 + D-010 组合加速）**：同屏两区两步——Init 常驻「2 AGENT」区列出本机已装 agent；第 1 步 `wz>` 输任务号（`n<num>`=强制新会话），第 2 步 `agent>` 输模型号后启动；无第二屏、无行展开，选择动作本身不跳过。**两步文法同构**：数字+Enter = 选 / Enter 空 = 默认（D-005 解析）/ q = 返回（第 2 步取消零 spawn）。**屏幕静态**——只在状态转换时重绘一次，键入过程零重绘；序号两区同款 `[ n]` 芯片同缩进；亮黄=当前激活步骤的可输入索引（D-013 预留色，阶段高亮保留），非激活步骤暗灰，另由 `<< step N` 标记指示。**组合加速道（D-010）**：默认视图封顶 9 行，两位数 `<任务><agent>` 一次直启（`n<组合>` 强制新会话），门禁照常；`a` 全量视图组合失效、数字回退行号。
- COMMAND 操作区采用三列固定单元格，三行的第 2/3 个入口始终从同一终端列开始，不再被前项文案长度推移；二级操作仅 `a/r/q`。历史 Grok 专属 `d` Dashboard 与 launch menu 项均删除，启动菜单只保留 Init、PowerShell、CMD（D-016）。
- 顶栏/HUD 在项目名旁显示当前页签 agent。

#### 6 · 并发纪律

同一任务默认串行；`.wz-handoff.md` 的 Last agent + 时间戳仅作提示，不引入锁或常驻协调（KISS）。同任务开多个不同模型窗格属于用户自裁量，工作台不阻止。

#### 7 · 实施切片（状态）

1. ✅ live：`open-project.ps1 -Agent` + `desk.lua`/`projects.lua`/`sidebar.ps1` 读可选第三列动态 route id；未绑定时采用开放探测第一项；`status.lua` 显示当前 agent；
2. ✅ live：Init 向导 `c` 现为 4 步（名 → 位置 → **Agent / CLI** → 确认）；同一选择同时决定启动程序与默认 agent；Init/F3/F6 共用无产品白名单的开放探测器；
3. ✅ 本仓：`live-workbench/` 快照逐文件 diff 同步、`desk-roots.example.tsv` 三列表头、README/cheatsheet 回写；
4. ⚠️ 部分：脚本化交接演练已过（`prototypes/handoff-smoke/`：交接文件 → 基线 Verify FAIL → 接手完成 → Verify PASS → 回写 handoff）；**交互部分待用户 live 冒烟**：Ctrl+F5 后 F6 在 kimi 任务上开 kimi 页签、向导选 agent、open-project `-Agent kimi`。
5. ✅ 平权去 grok 耦合（2026-08-10，D-005）：F6/续聊/布局族按 agent 路由（修掉 F6 写死 grok、resume 只支持 grok 两个核心断点）；Init 面板 codex 会话枚举 + 三路路由 + `Start-CodexTab`（`Read-CodexSessionSummaries`，冒烟 `smoke-codex-sessions.ps1` ALL PASS）；sidebar `Start-AgentHere` 三路 + R1 门禁；profile/cheatsheet/README/INSTALL 平权措辞；`Install-WZ` Doctor 改为 ≥1 已装 agent 即通过；`open-project` 缺省解析按 D-005、`-Continue`/`-Prompt` 三路映射；load guard 正则泛化防 false pass。交互冒烟待用户。

D-004 已定案；切片落地期间 Grok 默认行为不变（agent 列缺省 = grok）。

### Terminal UI iron rules (wizard / choosers)

| ID | Rule |
|----|------|
| **R-UI-1** | 信息分区舒展：身份摘要 / 主选项列表 / 次要动作 / 输入行 之间用空行与分隔线隔开，禁止全部挤在一角。 |
| **R-UI-2** | **灰色（Gray / DarkGray）只用于静态说明**（章节标题、提示、不可点的元信息）。**禁止**把有效选项画成灰色。 |
| **R-UI-3** | 一切可点选项（含 `[b] back`、`[q] cancel`、`[0]`、数字项）必须用 **White / Yellow / Cyan** 等高对比色。新建位置的手输父目录入口仅为 `[0]`，不得保留 `[9]` 别名（D-015）。 |
| **R-UI-4** | **无意义的超链接禁止可点**：向导里 CLI 的 `.exe/.cmd/.ps1` 只显示文件名；终端默认 **单击不打开链接**，需 **Ctrl+单击**（或中键）才打开有意义的 `file://` / URL。误点导致错误 cwd / trust 提示视为缺陷。 |
| **R-UI-5** | F3 **新建向导**（`-WizardOnly`）：`q` 取消或流程正常结束后 **自动关闭该标签**，不得留下空 `PS>` 要求用户再 F4。 |

实现：`bootstrap.ps1`（`Stop-Wizard` / `Format-CliLeaf`）、`options.lua` 鼠标、`hyperlinks.lua`；违规视为缺陷。

### Core key map (current local truth · F-013 / D-007)

| Key | Action |
|---|---|
| 新页签 / ＋ / 冷启动 | **Init 面板**（静态屏 + 行输入，D-009/D-010）：`wz>` 输任务号（`n<号>`=新会话；`<任务><agent>` 两位数=一次直启，默认视图 ≤9 行）→ `agent>` 输模型号 / Enter=默认 / q 取消零 spawn；序号 `[ n]` 芯片两区同制式，亮黄=可输入索引（D-013 预留色） |
| F1 | Cheatsheet 面板开关（可能被 Windows 帮助吞；面板内 q 兜底） |
| F3 | 新建项目向导（`-WizardOnly`） |
| F4 | Close pane |
| F5 | Reload 配置（`Ctrl+Shift+R` 为应急冗余） |
| F6 | 三栏 AI 桌：先弹**全量已装 agent 平权选择器**（默认 = desk-roots 第三列路由排第一，↑↓+Enter 确认，Esc 取消零 spawn；单一已装 agent 自动跳过；未绑定页签只弹 toast） |
| F7 | Left Explorer（绑当前页签 DESK） |

**无 Leader 层（D-007，2026-08-13 用户决定退役）**；F8–F12 刻意不绑；F2、`Ctrl+;` 归 agent CLI；键仅 WezTerm 聚焦生效。面板本地键（c/n/s/r/a/q/数字）承担一切非全局动作；无任何产品专属键。

### Session cwd (F-005) + create freeze (F-008)

Agent 顶栏 cwd = 进程启动 cwd；会话内 `cd` 不改顶栏。`open-project.ps1` 优先使用 `wezterm cli spawn` / `--new-tab`，禁止裸启 Agent 形成叠加的独立 OS 窗口。

新建任务：Init 面板按 `c` → 项目名 → 冻结路径 → 单一 Agent/CLI 选择 → 确认；随后写 `desk-roots` + `.wz-project`，并只用该 PATH 启动所选 Agent。位置页手填父目录只保留 `[0]`。

### Workbench UX fixed / in progress

| 项 | 状态 | 说明 |
|---|---|---|
| F-006 侧栏与对话同根 | **已改 live config** | 焦点在 Grok 时 F7 以 `--cwd` 为 DESK；页签级 desk；`open-project.ps1` 写 desk-roots |
| F-006 侧栏可点击打开 | **已改** | 文件 OSC-8；文件夹数字进入；0 上级 |
| 顶栏本页签动态任务 | **已改** | 状态跟 **当前标签** 窗格 cwd；HUD 随页签切换自动刷新 |
| 任务初始化面板 | **冷启动+新标签统一** | `default_prog`/Ctrl+Shift+T → `bootstrap.ps1` 表格；纯 Shell=Init 面板按 `s`（或 launch menu 的 PowerShell 项）；分屏仍 PS；`no-bootstrap` 可关 |
| Init 面板卡顿 | **已改 live** | 原为每次按键全量重扫 grok/kimi/codex 会话目录；现行缓存 + 脏标记（`$script:RowsDirty`），仅 `r`/ `a`/ 动作后重建，j/k/数字/Enter 纯渲染缓存行 |
| Init 列表 Act\*/排序 | **已下线/已改** | Act\* 列与整条 marks 管线（缓存+后台刷新器+空闲轮询）已**整体拆除**（用户 2026-08-13：优化不出效果，干掉）；列表改为 `# DateTime Tag Project Path Model Title`，Path 列头部保留、超长尾端 `~` 截断；bound 层按最近活跃倒序 |
| Init 启动与 agent 解耦 | **已改 live（同屏两区两步 + 开放探测）** | 本机通过包/清单/版本资源/用户级独立 CLI 静态能力证据/本地兜底注册探测到的全部 Agent 常驻「2 AGENT」区，不设产品白名单；冷启动必重扫，`r` 在任务步和 Agent 选择步都可重读持久化 PATH。`wz>` 选任务 → `agent>` 选 Agent，取消零 spawn；R1–R6 不变。COMMAND 采用三列固定单元格，`c/s/q` 等后续入口纵向对齐；Grok 专属 Dashboard 已从面板和启动菜单清除。屏幕仅在状态转换时重绘；亮黄仍只代表可输入项（D-013）。 |
| 读取/启动进度语义 | **D-017 已加固** | 文件与会话读取先枚举一次并共享一个全局计数轴，完成合并和发布后才到 100%；外部 Agent 就绪时长不可知，启动阶段改用不定进度动画，不显示虚假百分比。 |

### Known residual pain (workbench backlog seeds)

- 已打开的旧 Explorer 窗格不会自动跟新对话；需 F4 关掉后 **先点 AI 窗格再 F7**。
- 全局键依赖 WezTerm **窗口聚焦** 与笔记本 `Fn` 层（F 键）。
- 个人「彻底想要的样子」其余缺口待继续收集。
- 多模型接手同一任务 ~~无设计（F-010）~~ → 已有设计（D-004）并完成平权落地（D-005，2026-08-10）；残留：codex 无标题会话默认被 Layer C 过滤（`-All` 可见）、kimi `-p` 为一次性非交互。
- 配置在 home 树；第三方用 `Install-WZ.ps1`，作者本机仍以 live 为准。
- **`bootstrap.ps1` 依赖 UTF-8 BOM**：PS 5.1 对无 BOM 文件按 GBK 误读，中文/颜文字会炸解析；编辑工具写回会剥 BOM —— 改后必须补回 BOM 再跑 ParseFile 校验。

## Current package target (workbench-first)

**PKG-001**：门禁 + 项目名/路径冻结（D-003 / F-007 / F-008）+ 可移植安装（F-009）已落盘；收口前补齐**验收清单**并消除契约漂移。

下一步（PKG-002 候选）：

1. 用户批准下方验收清单（或增删项）
2. 在 live 会话逐项打勾；缺口只改 live + 回写本仓契约
3. 作者宣布「工作台达标」后再开封装包

**不在当前主线：** 完整 `SKILL.md` 正文、多 skill 打包、对外分发。

## Deferred: skill encapsulation (post workbench)

当用户宣布工作台达标后，再开封装包，预期包括：

1. 以 **WZ-AiWorkBench** 为族名的 skill（可能多个）
2. Agent 对 WS/DESK、键位作用域、Grok 共存、cwd 纪律的可执行协议
3. 可选：portable assets / 安装与同步逻辑
4. 验收：在真实 WezTerm 流上对照 F1/F3–F7 键位、Init 两步流与启动脚本

## Acceptance (phase-split)

### Workbench phase (current)

- [x] 产品族名定为 WZ-AiWorkBench（D-001）
- [x] 明确 skill 封装后置（D-002）
- [x] 门禁 R1–R6 + 新建路径冻结（F-007 / F-008 / D-003）
- [x] 第三方安装路径 `Install-WZ.ps1`（F-009）
- [ ] 用户批准「工作台达标」验收清单（草案见下）
- [ ] 清单项在 live 会话中全部通过
- [ ] 行为契约与 live / `live-workbench/` 一致（无关键漂移）

### Workbench acceptance checklist（草案 · 待用户批准为 D）

> 批准后可将本表升格为正式验收门禁；未批准前仅作执行清单草案（P）。

#### A · 身份与门禁

| # | 项 | 通过标准 |
|---|---|---|
| A1 | Init 任务表 | 冷启动 / 新标签出现 Init 表；TASK 来自 desk-roots，home 不在正式 TASK |
| A2 | SYS 拒开聊 | 弱路径不得以正式项目身份开任何 agent：Init SYS 行拒 Enter；未绑定页签 F6 只弹 toast 不开页签；sidebar 在 home 按 `b`/`g` 被拒 |
| A3 | 新建冻结 | Init `c` 四步（名→位置→Agent/CLI→确认）：一次写目录 + desk-roots（AI 选择显式三列）+ `.wz-project`；所选 CLI 与默认 agent 必须同一身份，位置手输入口仅 `[0]`；agent 仅以该路径为启动 cwd |
| A4 | 路径槽 | 左状态栏路径槽 = 当前页签 DESK（强路径），与 agent 顶栏 cwd 一致 |
| A5 | 项目名 | 页签/列表「项目名」= desk-roots 绑定名，**不是**会话标题 / cwd leaf |

#### B · 键位与布局

| # | 项 | 通过标准 |
|---|---|---|
| B1 | F6 三栏 | 在绑定的强路径任务上 F6 → 先出**全量已装 agent 平权选择器**（默认 = 第三列路由排第一，↑↓+Enter），确认后开「agent + Shell + 监视」三栏；Esc 取消零 spawn；未绑定页签只弹 toast |
| B2 | F7 同根 | 先点 AI 窗格再 F7 → Explorer 根 = 页签 DESK / agent 启动 cwd |
| B3 | F1 速查 | cheatsheet 面板开/关（F1 被 Windows 吞时面板内 q 可关） |
| B4 | Init 两步流（静态屏 + 组合加速） | `wz>` 输任务号（或 `n<号>` 新会话；两位数 `<任务><agent>` 一次直启，默认视图 ≤9 行）→ 2 AGENT 区待命 → `agent>` 输模型号 / Enter=默认 / `r` 即时重探测 / q 取消零 spawn；AGENT 区等权展示全部开放探测结果；COMMAND 三列固定对齐且无产品专属 `d`；屏幕只在状态转换时重绘一次 |
| B5 | 重载 | F5（或 Ctrl+Shift+R）toast「配置已重载」 |
| B6 | 不抢 agent | F2、`Ctrl+;` 仍归 agent CLI；工作台键仅 WezTerm 聚焦生效；**无 Leader 层** |

#### C · 启动与可移植

| # | 项 | 通过标准 |
|---|---|---|
| C1 | open-project | `open-project.ps1` 用 wezterm spawn 页签，不叠独立 OS 窗 |
| C2 | Doctor | `Install-WZ.ps1 -DoctorOnly` 与 Init 使用同一开放探测器；≥1 个由开放元数据/静态能力/本地注册确认的 Agent 即通过 |
| C3 | 纯 Shell 逃生 | Init 面板按 `s` 可得不走任务流的纯 PowerShell 页签 |
| C4 | 快照同步 | 改门禁/键位后 `live-workbench/` 与 `~\.config\wezterm` 无关键契约漂移（md5 一致 + BOM 断言过验证器） |

#### D · 已知可接受残留（不阻塞达标）

- 旧 Explorer 窗格不自动跟新对话（F4 后重开）
- 笔记本 Fn 层、IME 抢键需用户环境自理
- codex 本机未安装，其路径仅经静态/脚本化验证（D-006 已拉平门禁级硬化）
- M-3：open-project.ps1 可移植性残留（硬编码安装目录 + cli 文本解析），留后续包
- macOS/Linux/WSL 宿主明确不支持；这是纯 Windows 项目边界，不是待补兼容项

### Packaging phase (later)

- [ ] WZ-AiWorkBench skill 族命名与目录落盘
- [ ] `SKILL.md`（及可能的姊妹 skill）可被 Agent 正确触发
- [ ] 原则 + 键位 + 任务模型 + 启动纪律写入 skill
- [ ] 真机流程验证 + L3 冻结 v0.1
