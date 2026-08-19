# Agent 事故审查与工作流坑点报告（2026-08-19）

范围：WZ_AiStarCube 项目 2026-08-13 ~ 08-19 期间的四起事故 + 一起流程事故。
动机：同一工作流被两个 Agent（Kimi / Grok）先后修坏三次以上，需要把「坑点—Harness 短板—防护」说透，而不是继续指望运气。

---

## 一、事故编年史（全部有据可查）

### I1 · 08-14 BOM 剥离爆炸（Kimi）

- **经过**：用编辑器改 `bootstrap.ps1` 收尾一行，未重挂 UTF-8 BOM。PS 5.1 把无 BOM 的 UTF-8 中文注释按 GBK 误读 → parse 爆炸，用户实测 Init 打不开。
- **根因层**：① PS 5.1 的无 BOM=ANSI 假设是环境地雷；② 编辑工具静默剥 BOM；③ 交付前没有跑既定的 `bom-and-parse.ps1`（规程已存在）。
- **证据**：DECISIONS.md 2026-08-14 F-014 事件第 (4) 节。

### I2 · 08-13 Init 渲染器 v1 方向错误（Kimi）

- **经过**：为治闪烁做了「绝对坐标局部更新」渲染器 v1，用户实测**更闪**，当日推翻重做 v2（无清屏顺序覆写）。
- **根因层**：在没有真实终端验证能力的情况下，基于错误的心智模型（闪烁=重绘本身，而非空窗期）施工。方案级错误，测试无法拦截——因为根本没有"视觉流畅度"的自动化断言。

### I3 · 08-14 user-var 钉住方案从未生效（Kimi）

- **经过**：页签防污染方案依赖 OSC 1337 SetUserVar + status.lua 检测。两天对抗性审查后查明：**该代码从未被加载过**——WezTerm 自动重载只盯主配置不盯模块文件，且 `PaneInformation.user_vars` 在本机未验证。用户看到「完全不行」时，新代码其实一行都没跑过。
- **根因层**：方案建立在未验证的宿主 API 假设上；「部署了」≠「生效了」；缺少端到端生效性验证（ls-fonts 只证明配置可加载，不证明行为正确）。

### I4 · 08-19 splat 错绑 → AGENT 区归零（Grok）

- **经过**：Grok 为加条件 `-Refresh`，把 bootstrap 调探测脚本的内联命名参数改成数组 splat `@('-WorkbenchDir', $root)`。PS 5.1 对此做**纯位置绑定**：`WorkbenchDir` 得到字面量 `"-WorkbenchDir"`，真实路径落进 `UserPathOverride` → PATH 被覆写成 workbench 目录 → 三类发现源全灭 → 0 个 agent。
- **隐身机制**：调用点 `try{}catch{}` 全吞 + UI 优雅降级为「未检测到」空态——功能死透，界面如常。
- **实证过程**：探针二分（内联=5 / splat=0）+ 参数转储（错绑实况）+ 逐阶段解剖（全扫=5）。Grok 自己的单测全绿，因为单测**直接调 discovery，绕开了它改动的调用方式**。
- **证据**：`prototypes/hardening-smoke/probe-bisect-*.ps1`、`probe-param-dump.ps1`。

### I4b · 08-19 List[object] DLR 绑定器 bug（Grok 代码潜在缺陷，修复 I4 后暴露）

- **经过**：splat 修好后冷启动仍是 0 家。新日志抓到 `[System.ArgumentException] 参数类型不匹配`，.NET 堆栈定位到 `PSEnumerableBinder.MaybeDebase`——`Read-WzInventoryCache` 返回的 `List[object]` 经管道枚举时，在 bootstrap 的热 DLR 会话里触发 PS 5.1 绑定器 bug。换成普通数组即愈。
- **意义**：这是「前序 bug 掩盖后序 bug」的典型——splat 的 `UserPathOverride` 恰好绕过缓存读取路径，把这个 bug 掩住了。修一个、冒一个。
- **教训兑现**：新加的 `discovery-debug.log` 在本次立刻产出价值（从瞎猜缩短到一次复现定位）。

### I5 · 08-17→08-19 未提交加固被覆盖丢失（流程事故，无代码 bug）

- **经过**：08-17 Kimi 给 `Install-WZ.ps1` 加的 known-folder 探测加固未提交；08-19 Grok 会话在施工时整体覆写了该文件，加固**无声消失**，直到 08-19 冲突评估时才被发现。
- **根因层**：两个 Agent 会话在同一工作区接力施工，未提交的工作区改动对后一个会话不可见也不受保护。Git 的并发保护只管已提交历史，不管工作区。

---

## 二、这个工作流的坑点全景

按「触发频率 × 隐蔽性」排序：

| # | 坑 | 触发者 | 隐蔽机制 |
|---|---|---|---|
| P1 | PS 5.1 无 BOM 文件按 GBK 误读 | 任何编辑器/Edit 工具 | 保存时无任何提示，运行时才炸 |
| P2 | PS 5.1 数组 splat 静默改位置绑定 | 想"优雅"地条件传参时 | 不报错，参数错位到别的参数里 |
| P3 | PS 5.1 DLR 对 `List[object]` 等泛型枚举的绑定 bug | 返回泛型集合经管道 | 仅在热会话（调用方跑过大量 DLR 调用点）时触发 |
| P4 | `try{}catch{}` 全吞 + 优雅降级 UI | 防御性编程的好心 | 功能死亡但界面正常，肉眼难辨 |
| P5 | live(`~\.config\wezterm`) ↔ 仓库镜像双写 | 每次改配置 | 两边都能跑，忘了同步就漂移 |
| P6 | WezTerm 自动重载只盯主配置文件 | 改 `workbench/*.lua` 后按 F5 | 看起来重载了，其实模块没换 |
| P7 | 自动化宿主 shell 剥离环境变量（ProgramFiles 等） | CI/Agent 宿主里跑安装器 | 在真桌面好好的，在自动化里假阴性 |
| P8 | 嵌套 PowerShell stdin 管道吞帧 | 测试基建套娃调用 | 产品没坏，测试环境假象 |
| P9 | 多帧渲染输出（加载帧在前、终态帧在后） | 写输出断言时 | 断言打在第一帧上必误判 |
| P10 | 未提交工作区在多 Agent 会话间无保护 | Grok/Kimi 接力施工 | 后到会话整体覆写，前者改动无声消失 |

---

## 三、Grok Harness 的实测短板

基于 I4/I4b/I5 的直接证据，以及其留在 DECISIONS.md 的施工记录：

1. **验证层级错位（最核心）**。它的记录显示每轮都跑了测试——但测的是被改文件本身（discovery 单测），不是系统行为（Init 真实打开后 AGENT 区有几家）。改的是调用方式，却用绕开调用方式的测试来验证。「单测全绿」被当成了「系统正确」。
2. **规程可见但未必生效**。`bom-and-parse.ps1` 规程在仓库里躺着，其会话仍交出了丢 BOM 的 sidebar.ps1（我接手时 `BOM reapplied`）。无法确认其 Harness 是否加载了 AGENTS.md；从结果看，项目级规约没有进入它的交付检查清单。
3. **施工路径是「直改 live + 装回仓库」**，依赖 Install-WZ 的自动备份兜底，自己没有动手快照的习惯。
4. **长处也要承认**：File.Replace($null) 抛错的根因定位、外部 CLI 冷启动分段计时（kimi 5.2s/codex 3.1s/agy 2.7s）都很扎实，性能轮的改造方向正确、文档记录完整。问题不在分析能力，在**验证纪律**。

## 四、Kimi Harness 的实测短板（自我暴露，同样依据证据）

1. **I1（BOM）是我犯的**，且发生在规程明文写着我名字的场景里——我知道规程，仍漏跑。说明「知道」不等于「做了」，没有强制门禁的规程对我也一样失效。
2. **I2（渲染器 v1）是方案级错误**：没有真实终端验证手段时，我基于错误心智模型施工了一整轮，靠用户实测才推翻。自动化断言覆盖不到「视觉流畅度」这类体验属性。
3. **I3（user-var 钉住）建立在未验证的 API 假设上**，且两天里三轮修补都打在「从未被加载的代码」上——修不存在的故障。「部署了≠生效了」这层验证缺失是我的系统性盲区。
4. **本轮我也在测试基建上踩了 P8/P9**（嵌套管道吞帧 + 多帧误解析），花了几轮才分清「产品 bug」与「测试假象」。
5. **跨轮状态靠压缩笔记接力**，笔记错一处，后续修复就偏一处（本轮笔记把 step-2 的 M2-1 预期写错，实测才发现该路径本就 TryParse 无患）。

## 五、适配所有 Agent 的优化建议

### 已落地（本轮施工）

- `AGENTS.md` 新增**施工红线七条**（BOM 强制、三件套门禁、调用约定连带测试、禁 splat、禁无日志空 catch、live 快照+镜像对拍、多帧断言规则）——任何 Agent 打开仓库第一眼可见。
- `test-init-e2e.ps1`：**用户视角行为断言**——AGENT 区行数必须等于探测清单数、三区标题必现、无红色错误样板、r 刷新后不变。本次事故类型永久免疫。
- bootstrap 探测调用点：内联双分支 + `discovery-debug.log` 失败留痕（已证明价值）。
- `agent-discovery.ps1`：`PositionalBinding=$false`——位置误绑从此大声报错。

### 建议落地（待你批准）

1. **单一入口 `scripts/verify-gate.ps1`**：把三件套（bom-and-parse + e2e + validate_project）+ 条件项（lua 配平/ls-fonts/load guard）打包成一条命令，红线第 2 条引用它。降低"做对的事"的成本，比提高"做错的事"的惩罚更有效。
2. **git pre-commit hook 跑 bom-and-parse + e2e**：提交级强制，Agent 忘跑也拦得住。
3. **接力交接协议**（见第六节）：入会话先 `git status` 检查未提交改动。
4. **冒烟断言扩面**：LIST 区行数=desk-roots 绑定数、COMMAND 三行网格列对齐断言——把"界面什么样算对"全部代码化。

---

## 六、PPS 协议缺陷评估

### 有效的部分（继续使用）

- **权威分级（M/F/D/H/P）**：D-011~D-017 的决策沿革、supersede 链清晰可查，多轮返工没有丢过"为什么"。
- **验证器真实抓到过事故**：BOM 断言在 08-14 收口时抓获 cheatsheet/open-project 两处漏挂；CONTEXT 行数硬限本轮也拦了 81 行超限。
- **L0 恢复包 + Workset Manifest**：上下文体积受控，本轮接手没有翻全仓。

### 缺陷（按严重度排序）

1. **单写入者假设已被现实打破（最严重）**。协议明文「主任务是状态文件、项目地图、当前产物和覆盖表的唯一写入者」，但你的实际用法是 Grok + Kimi **接力甚至交替施工同一仓库**。PPS 没有任何 Agent 间交接规则：未提交工作区无保护（I5 的直接成因）、DECISIONS/CONTEXT 双写无合并约定、对方施工风格（直改 live）无约束。**这不是执行问题，是协议覆盖盲区。**
   - 最小补丁建议：AGENTS.md 加「接力交接」小节——接手先 `git status` 看未提交改动（有则先 diff 理解，不得整体覆写）；先跑 resume_packet；施工完成要么提交要么显式交接说明。
2. **验证是声明式，不是强制式**。「声称完成前运行 Verify」写在纸上，但没有检查点机制保证执行。I1/I4 两轮事故中，两个 Agent 都"部分遵守"——跑了自己选的子集，漏了致命的另一个。红线七条是补丁，但**靠自觉的协议条款对任何 Agent 都是弱约束**（包括我）。
3. **结构覆盖 ≠ 语义正确**。覆盖表只证明"引用了"，不证明"对了"。协议自己也承认（「验证器通过只代表结构覆盖」），但现状是结构验证绿了之后没有第二层防线——行为断言（e2e）这轮才补上，且是项目级而非协议级。
4. **CONTEXT.md 80 行硬限 vs 决策增多**：D 条目已到 17 个，覆盖表行数持续顶格，被迫压缩记录粒度。建议允许覆盖表拆出 `docs/coverage.md` 或放宽到 120 行。
5. **Status Events 无归档策略**：DECISIONS.md 已 390+ 行且只增不减，L0 读取成本线性上涨。建议按月归档到 `docs/decisions-archive/`。
6. **live/镜像一致性靠手工 md5 对拍**：协议的资产模型（core/supporting/reference）管 Git/LFS 副本，管不了"运行中配置 vs 仓库快照"这类活状态。建议把镜像对拍脚本化进 verify-gate。

### 总结论

PPS 对「个人串行推进」是合格的，它的缺陷不是设计错误，而是**适用范围被实际用法超出了**：你现在是多 Agent 接力 + 双写活配置，协议需要补「接力交接」和「强制门禁」两块，而不是推翻。

---

## 附：本轮修复清单

- bootstrap.ps1：探测调用改回内联双分支（永久禁 splat 注释留档）+ catch 落 `discovery-debug.log`（含 .NET 堆栈）。
- agent-discovery.ps1：`PositionalBinding=$false` 硬护栏 + `Read-WzInventoryCache` 弃用 `List[object]` 改普通数组（DLR bug 规避）。
- Install-WZ.ps1：被覆盖的 known-folder 探测加固已补回（I5 的遗失件）。
- 新增 `test-init-e2e.ps1`（9 项行为断言）、`AGENTS.md` 施工红线七条。
- 回归：六套测试全绿（open-discovery/loading-progress/codex-compat/sidebar-link/splash-wrap/init-e2e）、BOM+parse 0、live↔镜像 16 对 SHA 一致、ls-fonts exit=0、load guard OK、validate + readiness OK。
