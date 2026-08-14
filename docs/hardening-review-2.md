# 加固审查 Round 2（P-011 草案，待批准）

- 日期：2026-08-14 · 审查人：Kimi（主任务）
- 范围：P-008（D-006）收口后的全部新改动 —— DeepSeek 接入（F-014）、启动动画（Get-AgentSplashScript/Spawn）、D-009 静态屏行输入、D-010 组合直启、D-011/D-012 页签链、性能修复、D-013 颜色标准两轮施工
- 方法：只审不改。逐函数精读五条热路径（spawn/门禁/页签/输入/动画）+ 四个横切面（编码/宽度/性能/可移植性）+ lua 侧全模块 + 仓内辅助脚本
- 前一轮：P-008 → `docs/compat-hardening-review.md`（H-1~H-3/M-1~M-5/L-1~L-7 已全部闭环，M-3 留后续包）

## 结论速览

- **高危 0**——无新门禁绕过、无正常路径崩溃。R1–R6 在四条 Start-*Tab + F6 选择器链路全部在位。
- **中危 6**——M2-1 ~ M2-6。
- **低危 8**——L2-1 ~ L2-8。
- 验证器现状：BOM 断言、PS parse、lua 配平、宽度模态、ls-fonts、镜像 md5 全部每轮收口通过，本轮复审全部仍为绿。

---

## M2 · 中危

### M2-1 Init 主循环超长数字输入可直接崩面板

- 位置：`bootstrap.ps1` 主循环 `[int]$line` / `[int]$digits` 转换（3064/3083/3087/3106 行一带）
- 现象：`wz>` 输入 11 位以上数字（如手滑 `99999999999`）→ Int32 转换溢出抛 terminating error，主循环无 try/catch → **Init 面板进程崩溃退出**
- 证据：组合分支只判 `Length -eq 2`；超长数字落入 `[int]$line` 直接 cast
- 建议：数字分支入口加长度上限（`$line.Length -gt 4` 视为未知命令）或改用 `[int]::TryParse`

### M2-2 Find-AgentExe 对空 LOCALAPPDATA 无护栏（与 D-006 已修点同族）

- 位置：`bootstrap.ps1` Find-AgentExe codex 分支（2348–2350 行）
- 现象：精简环境（spawn shell/CI）`$env:LOCALAPPDATA` 为空 → `Join-Path $null …` 抛错 → Get-InstalledAgentPeers 崩溃 → Init 打不开
- 证据：D-006 在 Install-WZ.ps1 修过同一类问题（空值护栏）；lua 侧 `agent_fixed_candidates` 也有 `apd ~= ""` 护栏——唯独 bootstrap 这里漏了
- 建议：照搬 Install-WZ 的 `if ($la) {…}` 护栏模式（kimi/deepseek 分支的 USERPROFILE/APPDATA 同理一并补）

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
