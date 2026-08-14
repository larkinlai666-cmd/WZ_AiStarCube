# 加固审查 Round 2（P-011，已施工并回归通过）

- 日期：2026-08-14 · 审查人：Kimi（主任务）
- 范围：P-008（D-006）收口后的全部新改动 —— DeepSeek 接入（F-014）、启动动画（Get-AgentSplashScript/Spawn）、D-009 静态屏行输入、D-010 组合直启、D-011/D-012 页签链、性能修复、D-013 颜色标准两轮施工
- 方法：只审不改。逐函数精读五条热路径（spawn/门禁/页签/输入/动画）+ 四个横切面（编码/宽度/性能/可移植性）+ lua 侧全模块 + 仓内辅助脚本
- 前一轮：P-008 → `docs/compat-hardening-review.md`（H-1~H-3/M-1~M-5/L-1~L-7 已全部闭环，M-3 留后续包）

## 施工结果（2026-08-14 15:33 轮，用户批准全量）

- ✅ M2-1（step-1 两处数字分支长度上限 + ScreenDirty）、M2-2（Find-AgentExe 三分支 + wizard 第二现场空值护栏）、M2-3（Install-WZ deepseek 四平权）、M2-4（向导 spawn 用 `$Exe` 全路径）、M2-5（仓内四脚本 9 处黄色归位）
- ✅ M2-6 按方案 A：launch_menu 移除三个裸 agent @ home 入口（D-003 精神对齐）
- ✅ L2-1 / L2-2（EOF 防死循环）/ L2-3（非 shell 补 R1 复验）/ L2-5（`r` 键清 AgentPeers 缓存）/ L2-7（splash 令牌罕见串）/ L2-9（零 agent 提示补 deepseek）
- 👁 留观察：L2-4（desk.lua 认不出 node 版 deepseek）、L2-6（deepseek 恒 -NoExit 不对称）、L2-8（splash 贴底漂移）
- 回归：BOM/parse 0、管道冒烟 ×5 exit 0、零 agent ×2、宽度模态 psw=100、lua 配平 10/10、splash 单测 PASS×2、ls-fonts exit=0、镜像 md5 10/10、残留 Yellow 终审 = 输入前缀专属（D-013 有意保留）


## 结论速览

- **高危 0**——无新门禁绕过、无正常路径崩溃。R1–R6 在四条 Start-*Tab + F6 选择器链路全部在位。
- **中危 6**——M2-1 ~ M2-6。
- **低危 8**——L2-1 ~ L2-8。
- 验证器现状：BOM 断言、PS parse、lua 配平、宽度模态、ls-fonts、镜像 md5 全部每轮收口通过，本轮复审全部仍为绿。

---

## M2 · 中危

### M2-1 Init 主循环超长数字输入喷红错误（实测修正：不崩但脏屏）

- 位置：`bootstrap.ps1` 主循环 `[int]$line` / `[int]$digits` 转换（3064/3083/3087/3106 行一带）
- 现象：输入 11 位以上数字（如手滑 `99999999999`）→ Int32 cast 抛 `InvalidCastFromStringToInteger`。**实测（printf 管道）：面板不崩、循环继续，但喷一段红色错误样板文，且 `ScreenDirty` 未置位 → 界面不重绘覆盖，红字残留**
- 证据：`wzbig-out.txt` 52-53 行错误记录 + 后续 `q` 正常退出 exit=0
- 建议：数字分支入口加长度上限（`$line.Length -gt 4` 视为未知命令）或改用 `[int]::TryParse`，并置 `ScreenDirty` 让提示行覆盖错误残留

### M2-2 Find-AgentExe 对空 LOCALAPPDATA 无护栏（与 D-006 已修点同族）

- 位置：`bootstrap.ps1` Find-AgentExe codex 分支（2348–2350 行）
- 现象：精简环境（spawn shell/CI）`$env:LOCALAPPDATA` 为空 → `Join-Path $null …` 抛错 → Get-InstalledAgentPeers 崩溃 → Init 打不开
- 证据：D-006 在 Install-WZ.ps1 修过同一类问题（空值护栏）；lua 侧 `agent_fixed_candidates` 也有 `apd ~= ""` 护栏——唯独 bootstrap 这里漏了。**同族第二现场：`Build-InstalledAiCliOptions` 2278 行 grok 回退同样裸用 `Join-Path $env:LOCALAPPDATA …`（零 agent 回归实测时复核发现）**
- 建议：照搬 Install-WZ 的 `if ($la) {…}` 护栏模式（kimi/deepseek 分支的 USERPROFILE/APPDATA 同理一并补；wizard 2278 行同修）

### M2-3 Install-WZ.ps1 不认识 deepseek（第三方装机断档）

- 位置：`Install-WZ.ps1` Doctor agent 列表（112 行 `foreach ($a in @('grok','kimi','codex'))`）、绑定列选择（249 行）、注释（46/109/281 行）
- 现象：Doctor 只探测 grok/kimi/codex——一台**只装了 deepseek** 的新机器会误报「No agent CLI found」；绑定列也不会选 deepseek
- 证据：F-014 四平权已在 bootstrap/launch/layouts/resume/desk/projects/open-project 全部落地，唯独安装器漏网
- 建议：Resolve-AgentExe 加 deepseek 分支（%APPDATA%\npm 落点），三处列表补第 4 位

### M2-4 向导 spawn 忽略已解析的 $Exe，改用裸命令名

- 位置：`bootstrap.ps1` Start-ProjectWithCli（2447–2461 行）
- 现象：`$invoke` 对 kimi/codex/deepseek 恒为裸名（`'kimi'`/`'codex'`/`'deepseek'`），依赖新 shell 的 PATH 解析；而向导上游 Build-InstalledAiCliOptions 可能正是经**显式回退路径**找到该 CLI 的（PATH 里没有）——Init 主面板用 $exe 全路径能起，向导链路却在新页签里报「找不到命令」
- 证据：对比 Start-*Tab（`$exe = Find-AgentExe` 全路径 host wrap）与 Start-ProjectWithCli（裸名）
- 建议：$invoke 优先取 $Exe 的文件名（现成逻辑只对 default 分支做）；或向导 spawn 改走与 Start-*Tab 相同的 $exe 路径

### M2-5 D-013 未清扫仓内辅助脚本（警告黄残留 9 处）

- 位置：`open-project.ps1` ×4（227/240/266/271 行 NOTE/WARNING）、`Install-WZ.ps1` ×3（Write-Warn 39 行 + 346/347）、`profile-snippet.ps1` ×1（48 行）、`cheatsheet.ps1` ×1（30 行 DarkYellow）
- 现象：D-013 规定亮黄 = 可输入专属；这些脚本的警告/提示仍是黄色系，用户看到会认知冲突
- 证据：本轮 D-013 只施工了 live 面板两文件（bootstrap/sidebar）
- 建议：警告/注意统一归 DarkCyan（次级注意）或 Cyan（信息）；`scripts/wezterm_load_guard.ps1` 的 WARN 黄（148/149 行）属 CI 诊断工具，可豁免或一并归位——待批准时定

### M2-6 启动菜单裸 agent @ home 与 D-003 精神冲突（需用户裁决）

- 位置：`launch.lua` launch_menu（324–338 行）：`◆ Kimi`/`◎ Codex`/`◇ DeepSeek` 均以 `cwd = home` 直接起会话
- 现象：从启动器（ShowLauncher）点这三项 = 在 home 目录开 agent 会话 → 产生 home-cwd 散落会话，正是 D-003/R1–R6 要防的「会话身份≠项目」污染（grok 的 home 入口当年即因此移除，F-007）
- 反方观点：它与 `■ PowerShell` 一样是刻意的逃生舱；Init 内 `s` 也提供纯 shell
- 建议（二选一，待裁决）：A) 移除三个裸 agent 项，只留 Init 面板/Dashboard/纯 shell；B) 保留但统一改名标注「逃生舱·非任务」

---

## L2 · 低危

| ID | 位置 | 现象 | 建议 |
|---|---|---|---|
| L2-1 | bootstrap.ps1 1612 注释 | splash 注释仍写「Single Yellow accent」，实际已 Magenta（D-013） | 改注释 |
| L2-2 | bootstrap.ps1 主循环 Read-Host | 重定向 stdin 耗尽且无 `q` 时 EOF 空转死循环（仅管道误用场景） | EOF 检测后 break |
| L2-3 | bootstrap.ps1 Start-ProjectWithCli 2420 | 只有 Test-Path 无 R1 复验（向导上游已拦弱路径，纵深防御缺口） | 补一行 Test-StrongProjectPath |
| L2-4 | desk.lua role_for_process 1201 | deepseek 是 node.exe 进程，按名识别落空 → HUD 角色显示「node.exe」（页签标题路径不受影响） | 角色识别加页签标题回退 |
| L2-5 | bootstrap.ps1 AgentPeers 缓存 | `r` 刷新不清 `$script:AgentPeers`——Init 开着时新装 CLI 不识别，需重开面板 | r 键顺手清缓存 |
| L2-6 | Start-DeepSeekTab 恒 -NoExit | agent 退出后页签残留 PS 提示符（grok/kimi 是即退即关）——为错误可见有意为之，但四家行为不对称 | 保持或统一，定稿写进 MAIN |
| L2-7 | Get-AgentSplashScript 令牌链式替换 | `__AGENT__` 的替换值若含字面 `__PROJ__` 会被二次替换（当前标签全为内部常量，不会触发） | 调换替换顺序或换不可能撞车的令牌 |
| L2-8 | splash 缓冲满屏滚动画 | CursorTop 贴底时原地重绘坐标漂移（300ms 后 Clear 自愈，纯视觉） | 可忽略；或首帧前先补 6 空行占位 |
| L2-9 | bootstrap.ps1 1455 | 零 agent 提示文案 `'(no grok/kimi/codex CLI detected)'` 漏了 deepseek（冷启动实测中肉眼可见） | 改为四家全名 |

## 附录：零 agent 冷启动回归实测（2026-08-14，用户点名场景）

方法：`prototypes/hardening-smoke/test-zero-agent.ps1` —— PATH 剥到只剩系统目录、USERPROFILE/APPDATA/LOCALAPPDATA 指向空假家目录，等价于「新设备 + 未装任何 agent CLI」。

- **S1 裸冷启（无绑定无 agent）**：Init 正常渲染，LIST 显示 `(empty) press c in COMMAND to create first task`，AGENT 区显示无 CLI 提示，`wz>` 正常，q 正常退出 exit=0 ✓
- **S2 超长数字**：见 M2-1（不崩但喷红残留）⚠️
- **S3 有绑定行（第三列=deepseek）但零 agent**：武装 → 提示 `agent 1-1 (Enter = 1 grok, q = cancel)`（legacy 兜底），Enter → 红提示 `! grok.exe not found` 留在信息区、无 spawn、Init 不关不崩、q 正常 ✓
- 静态复核：向导在零 agent 时恒提供 `PowerShell only (no AI CLI)` 选项，建项目 + 开 shell 链路完整；`$script:Grok` 启动即落兜底路径字符串，不会以 null 进 Test-Path；F6 零 agent 弹 toast 不 spawn；open-project.ps1 零 agent 明确报错文案
- 结论：**冷启动链路整体成立**——装 WezTerm → 跑 Install-WZ（0 agent 也能装完，Doctor 给警告不阻断）→ 开 wezterm 进 Init → `c` 建/绑项目（可选 shell 先用着）→ 装好任一 agent 后重开面板即全功能

## 复审仍为绿的既有防线（抽查）

- spawn 全部先过 R1 + CLI 存在性双门禁（四 Start-*Tab 逐一核）
- Set-SpawnedTabTitle 严格 `^\d+$` 全匹配 + 自指 guard + 轮转日志在位
- 引号转义链（splash 模板/exe/args/向导 here-string）逐点核，无注入面
- status.lua Init 检测：免费字段预过滤 + pcall + TTL 缓存，稳态零 mux 往返
- deepseek 会话哈希探测：sha256 对拍一致历史已验证，候选仅来自 desk-roots+favorites
- desk-roots 四个写出方仍全显式第三列 + temp+move 原子写
- 本轮实测：BOM 重挂 parse 0×2、管道冒烟 ×2 exit 0、宽度模态 psw=100、lua 配平 10/10、镜像 md5 10/10

## 建议施工顺序（批准后）

1. **M2-1 → M2-2**（崩溃类先行，改动小）
2. **M2-3 → M2-4**（装机/向导链路一致性）
3. **M2-5**（D-013 清扫，批量机械改）
4. **M2-6**（需用户先裁决 A/B，再动）
5. **L2 批清**（L2-1/2/3/5/7 随手；L2-4/6/8 可留观察）
