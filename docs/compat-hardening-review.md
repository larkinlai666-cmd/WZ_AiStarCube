# 兼容性与加固审查（P-008 提案 → 已批准为 D-006）

- 日期：2026-08-13 · 范围：live-workbench 全部模块 + open-project.ps1 + Install-WZ.ps1 + scripts/wezterm_load_guard.ps1
- 基准（项目理念）：R1–R6 门禁、D-004/D-005 agent 平权与缺省解析、F-009 第三方可移植、配置加载安全（load guard）、PS 5.1 目标运行时、中文 IME 友好键位、个人单机串行（不引平台化）。
- 状态：**2026-08-13 用户批准（「根据建议执行」）→ D-006，已按建议顺序施工完毕**。H-1/H-2/H-3、M-1/M-2、L-1–L-7 全部落地；M-4 随 M-1 落地；M-5 实测判定无需修；**M-3（open-project 可移植性）未施工，留待后续包**（需干净机验证）。冒烟 14/14 PASS、PS parse 0、load guard OK、live↔镜像 md5 一致。

## 结论摘要

| 级别 | 数量 | 主题 |
|---|---|---|
| 高 | 3 | F6/布局族 R1 门禁顺序与缺失、sidebar `b` 绕 R5、desk-roots 写出方 D-005 不一致 |
| 中 | 5 | lua 侧 kimi/codex 可执行性不检查、HUD 高频文件 IO、open-project 硬编码/文本解析、PATH 含 UNC 拖慢加载、sidebar 自动刷新待验证 |
| 低 | 7 | 键位文档漂移、双实现门禁清单漂移、写文件非原子、BOM 无护栏、ENVIRONMENT Verify 占位、d 键 grok 缺席、SCAN_ROOTS 含 .config |

## 高危

### H-1 F6/布局族：门禁在 spawn 之后或缺失（R1 可被绕过）
- 位置：`layouts.lua` `open_workbench_fresh`（spawn_tab 在 ~L55，`is_strong_path` 检查在 ~L60）；`open_dual_ai`（~L165）、`open_review`（~L206）、`open_focus_agent`（~L253）**完全没有**弱路径检查。
- 风险：`desk.ensure` 返回 nil/弱路径时，agent 已在 home/错误 cwd 下启动——正是 R1 要消灭的「裸 home AI 会话」，还留下孤儿页签。
- 修法：四个函数统一先 `is_strong_path` 门禁（不通过→toast+return），再 spawn；`agent_args` 之前解析 agent 与 cwd。
- 验证：在 Init 新页签（未绑定）直接 F6 → 应只弹 toast，不产生新页签；`desk-roots.tsv` 空表新机同样。

### H-2 sidebar `b` 绑定绕开 R5 门禁
- 位置：`sidebar.ps1` `b` 分支（~L1047）直接 `Write-DeskRootToFile`；该函数（~L67）无弱路径/保留名检查。
- 风险：用户在 home/Desktop 按 `b` 即把弱路径写进 desk-roots，绕过 `desk.lua set_root` 的 R5——门禁体系出现侧门。
- 修法：`b` 与 `Write-DeskRootToFile` 复用 `Test-WeakPath` + 保留名表，拒绝时红字提示。
- 验证：sidebar 进 `~` 按 `b` → 拒绝；desk-roots 不变。

### H-3 desk-roots 写出方对 D-005 不一致（grok 第三列被丢）
- 位置：`desk.lua write_map`（~L523 `a ~= "grok"` 时只写两列）、`sidebar.ps1 Write-DeskRootToFile`（~L99 同逻辑）。合规方：`open-project.ps1`、`Install-WZ.ps1`（显式写含 grok）。
- 风险：四个写出方两种语义。grok 绑定行被 lua/sidebar 改写后丢第三列；若日后卸载 grok，该行缺省解析漂移到 kimi（D-005 首装序），用户无感知。
- 修法：四个写出方统一「显式写第三列（含 grok）」。
- 验证：用 sidebar `b`/`f`、F6 绑定、open-project 各触发一次重写 → diff desk-roots 第三列不丢。

## 中危

### M-1 lua 侧不检查 kimi/codex 可执行性
- 位置：`launch.lua agent_args`（~L158）只对有 `has_grok()` 的 grok 做存在性兜底；kimi/codex 直接 `ps_command("kimi")`。
- 风险：desk-roots 绑了 kimi 但 kimi 已卸载 → F6/双栏/Review 打开一个报 `'kimi' 不是命令` 的废页签。D-005「单一 agent 缺失不得阻断其它」在 lua 启动路径未落实（bootstrap.ps1 今天已修，lua 侧未修）。
- 修法：launch.lua 增加 `resolve_agent_exe(agent)`（纯 io/env，仿 resolve_grok_exe，含 `.kimi-code\bin`、WinGet Links 候选；禁 run_child_process）；布局族启动前检查，缺失则 toast 引导改绑。
- 验证：临时把 PATH 中 kimi 摘掉（或改名 bin）→ F6 于 kimi 绑定任务 → toast 而非废页签。

### M-2 HUD/页签渲染高频读 desk-roots.tsv
- 位置：`desk.lua read_map/read_agent_map` 无缓存；调用链 `status.lua update-status`（500ms）+ `format-tab-title`（每次重绘）→ `name_for_path/agent_for_path` → 每次文件 IO。
- 风险：每 500ms × 每页签若干次小文件读；在 HDD/杀软慢的机器上是持续 UI 负担。
- 修法：给两个 reader 加 mtime 缓存（`io.open` 取 modified 时间戳比对，变化才重读）。
- 验证：性能计数（自测脚本）或 process monitor 观察；行为回归：改 desk-roots 后 HUD 下一次刷新即变。

### M-3 open-project.ps1 可移植性残留
- 位置：~L194 硬编码 `C:\Program Files\WezTerm\wezterm.exe`（Install-WZ 已用 `$env:ProgramFiles`）；~L278 `wezterm cli list` 文本解析（`Select-Object -Skip 1`）。
- 风险：非默认安装目录（Scoop/便携/(x86)）找不到 wezterm；`cli list` 输出格式跨版本变动 → window-id 提取失败退化为新窗口。
- 修法：改 `$env:ProgramFiles` + `(x86)` + Get-Command；`cli list --format json` + ConvertFrom-Json（旧版本无 json 时回退文本解析）。
- 验证：`open-project.ps1 -Agent kimi` 在本机与干净虚拟机各跑一次。

### M-4 launch.lua 配置加载期 PATH 全目录探测
- 位置：`launch.lua resolve_grok_exe`（~L37-44）对 PATH 每个目录 × 2 后缀做 `io.open`。
- 风险：企业机 PATH 含 UNC/网络映射盘时，`io.open` 每个可能阻塞数百 ms → 配置加载卡顿（上次 yield bomb 同类症状的另一形态）。
- 修法：跳过 `\\` 开头与空 PATH 项；先查固定候选再扫 PATH。
- 验证：load guard 通过；人为加 `\\10.0.0.1\x` 到 PATH 测配置重载耗时（F5 前后对比）。

### M-5 sidebar 自动刷新可靠性待验证（疑似跨 runspace 状态）
- 位置：`sidebar.ps1` `Register-ObjectEvent -Action { $global:WzExplorerFsDirty = $true }`（~L594）。
- 风险：事件 Action 在独立 session state 执行，`$global` 未必与主循环同一全局表——若如此，auto-refresh 实际从不触发（功能静默死亡）。
- 修法/验证（先做验证）：开 sidebar 后在 VIEW 里 `ni x.txt`，观察是否自刷新；若不刷新，改为 `$script:` 不可行（不同 runspace）时，主循环用 `Get-Event` 轮询事件队列代替标志位。

## 低危 / 卫生

| # | 位置 | 问题 | 修法 |
|---|---|---|---|
| L-1 | projects.lua L263 toast、Install-WZ L333-334、help.lua L157、sidebar.ps1 L2/L1026 | F8/F9/Leader(Alt+z) 已下线（keys.lua 精简）但文档/toast 仍教旧键 | 全文键位对齐 F1/F3–F7 现状 |
| L-2 | desk.lua vs bootstrap.ps1 | 保留名/弱路径双实现漂移：lua 有 `.kimi`，PS 无；PS 弱路径精确表含 `.grok\bin/sessions`，缺 `.kimi-code`/`.codex` 对应项 | 以 desk.lua 为基准对齐 PS 表；或共读一份 gates.json（更大改造，可选） |
| L-3 | desk.lua write_map / sidebar Set-Content / bootstrap Write-DeskRoots | desk-roots 直接截断写，非原子；崩溃中途丢绑定 | temp+move 原子写（参照已删的 project-marks.ps1 模式） |
| L-4 | bootstrap.ps1 / sidebar.ps1 / cheatsheet.txt | UTF-8 BOM 靠人肉维护（Edit 工具链剥 BOM → PS 5.1 按 GBK 误读 → 8-13 已咬两次） | validate_project.ps1 增加 BOM 断言，预提交钩子同步 |
| L-5 | ENVIRONMENT.md L15 | `Verify:` 仍是占位符「replace with…」 | 填 `powershell … validate_project.ps1` + load guard |
| L-6 | bootstrap.ps1 `d` 键（~L2700） | Dashboard 为 grok 专属；grok 缺席时 else 分支 `& $script:Grok dashboard` 打红字 | grok 缺席时提示并禁用 d |
| L-7 | projects.lua SCAN_ROOTS（~L22） | 深扫包含 `~\.config`，与 R2 精神相悖（产出会被弱路径过滤，但噪音） | 移除或只留 Desktop/Documents |

## 兼容性矩阵（现状评估）

| 维度 | 现状 | 说明 |
|---|---|---|
| PS 5.1（目标） | ✅ 主战场 | 已踩过并记录 BOM/GBK、无 EnumerationOptions 等坑；建议 L-4 护栏化 |
| PS 7+ | ✅ 兼容 | 未用 5.1-only API；`$Host.UI.RawUI` 路径一致 |
| WezTerm 版本差异 | ✅ 防御充分 | TabInformation/MuxTab 双形态、pcall 软化、load guard 在位 |
| agent 缺席组合 | ⚠️ 半成 | bootstrap/Install-WZ/open-project 已平权；**lua 启动族未平权（M-1）** |
| 干净机/第三方（F-009） | ⚠️ 小残留 | M-3 硬编码、`WZ_Skill` 修复兜底名（projects.lua ~L590）、L-1 旧键文案 |
| 中文 IME / 全角数字 | ✅ | Alt+z Leader、全角转半角、宽度按显示单元 |
| 路径含空格/中文/多盘 | ✅ | LiteralPath 纪律好；argv 数组传参 |
| 无 git 机 | ✅ | monitor_cmd 均 `Get-Command git` 判空 |
| 环境变量缺失 | ✅（今日修） | ProgramFiles 空值已护栏；LOCALAPPDATA 同理已查 |

## 建议施工顺序（如批准）

1. H-1 + H-2 + H-3（门禁闭环，半天内，全是局部改动）
2. M-1 + M-2（平权收尾 + HUD 缓存）
3. M-5 验证先行，再定修不修
4. L-1–L-7 一批顺手清

每个 H/M 项附验证命令，均可做成 `scripts/` 下的确定性检查进 Verify。
