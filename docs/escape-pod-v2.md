# F8 逃生舱 v2 — 设计（先于施工）

## 1. 截图事实（本轮不得再猜）

图 1：F8 舱列出五家 Agent，用户输入 `5` 启动了 **Kimi**，Kimi TUI 正常。  
图 2：同一批页签标题仍是 **`WZ_Skill | Agy`**。  
舱内只打印了 `cwd: G:\GrokProject\WZ_Skill`，没有项目列表。

两条同时坏：

| 槽位 | 现在实际用的身份 | 用户刚选的身份 |
|---|---|---|
| 项目 | 写死优先 `WZ_Skill`，否则 desk-roots 第一行 | 未问用户 |
| 页签 Agent | desk-roots 第三列（本机 `WZ_Skill → agy`） | Kimi |

这不是「Kimi 没启动」，是 **启动对了、外壳身份错了**。

## 2. 根因（代码位置）

**项目区暴力** — `escape-pod.ps1` `Get-WzPodCwd`：看见名叫 `WZ_Skill` 的绑定就用，否则用文件里第一行。没有 1 LIST，没有编号，没有「当前页签项目」。

**页签 Agent 错配** — 两刀叠在一起：

1. F8 是 `SpawnCommandInNewTab` 跑 `escape-pod.ps1`，**从未** `set-tab-title`。页签没有 `项目 | 实际 Agent` 契约。
2. 舱内 `& kimi.exe` 的宿主仍是 `powershell.exe`。`status.lua` `tab_tool` 把 powershell 判成 `Shell`。
3. `status.lua` 550–557 行：凡是 `Shell` 或 `App`，**用 desk-roots 第三列盖掉现场角色**。`WZ_Skill` 绑的是 `agy`，所以 Kimi 页签写成 Agy。

Init 开聊不那么明显，是因为 `Start-*Tab` 会写入 `项目 | Kimi`。F8 没走那条链，就踩中「空闲壳 = 任务默认 Agent」这条错误等式。

第三列的本义是 **新开任务时的缺省路由**，不是 **这个页签此刻在跑谁**。

## 3. 身份契约（先锁死再写代码）

三个槽位必须分开，禁止互相偷梁换柱：

| 槽位 | 权威 | 禁止 |
|---|---|---|
| 项目名 / 路径 | 用户在舱内选中的 desk-roots 行（名=左列，路径=右列） | 禁止因仓库叫 WZ_Skill 就特判；禁止用 cwd 叶子当项目名 |
| 页签 Agent | **这次启动选中的 Agent 标签**；写入 `项目名 \| Label` | 禁止用 desk-roots 第三列当现场页签角色 |
| 任务缺省 Agent | desk-roots 第三列，只用于「未选 Agent 时谁排第一」 | 禁止回写到已经选定的页签 |

R0 仍有效：Agent 列表开放探测、等权、零/一家/多家三种都要成立。专属 `--cwd`/`-C` 只是启动适配器。

## 4. 舱内交互（与 Init 同构，但更瘦）

F8 仍是 **一只键进舱**。舱是静态两区，不跑 `bootstrap.ps1`，不扫 grok/kimi/codex 会话目录。

```
1 LIST   desk-roots 绑定，编号 [1]…  名 + 路径
2 AGENT  开放探测结果，编号 [1]…  等权
```

语法与 Init 相同：

- 先输入项目号 + Enter，再输入 Agent 号 + Enter。
- 回车单独按下 = 当前区默认（项目默认 = 当前页签已绑定项目，否则列表第 1 行按名排序；Agent 默认 = 该项目第三列若仍在已装列表中，否则已装列表第 1 家）。
- 至多 9+9 时允许 `<项目><Agent>` 一枪（与 D-010 同形）。
- 只有 1 个项目则跳过 LIST；只有 1 个 Agent 则跳过 AGENT。
- 零项目：只给壳 + 提示用 F3/Init 建绑定，不伪造 home 为项目。
- 零 Agent：只给壳 + 提示装 CLI 或写 `agent-registry.local.tsv`。
- `q` 留在壳，不关标签。

**禁止** 再出现「没问项目就 `Set-Location WZ_Skill`」。

启动后：

1. 进程 cwd = 所选路径（Kimi/Agy/DeepSeek 靠 cwd；Grok 另加 `--cwd`；Codex 另加 `-C`）。
2. 用 `$env:WEZTERM_PANE` 调用 `wezterm cli set-tab-title --pane-id <自己> "<项目名> | <Label>"`。没有 pane id 则只设 `WindowTitle`，**禁止**无 id 的 `set-tab-title`（D-011）。
3. Agent 退出后壳留下，标题改为 `<项目名> | Shell`。

## 5. 页签绘制必须改的一条规则

`status.lua` 550–557 的「Shell/App → desk-roots 第三列」**删除或降级**：

- 标题已是 `名 | 角色` 且角色不是 Shell/App → **只信标题**。
- 前台进程名能对上已发现 Agent 的 exe 基名（`wezterm.GLOBAL.wz_agent_route_ids` / 发现缓存）→ 用进程，不用第三列。
- 真正的空闲 PowerShell 且标题无契约 → 显示 `项目 | Shell`，**不要**显示任务缺省 Agent。

第三列继续用于 F6/Init 的「默认排第一」，不用于粉饰现场。

## 6. 非目标

- 不在 F8 里做会话续聊扫描（那是 Init 的活，也是慢和炸的来源）。
- 不在 F8 里建项目（F3）。
- 不把 F8 做成第二个 Init。
- 不为 Grok 或 WZ_Skill 保留特权路径。

## 7. 施工顺序（批准后再动）

1. **先修 `status.lua` 页签角色**（所有 powershell 宿主都会受益，含现有 Init 漏设标题的路径）。
2. **再改 `escape-pod.ps1` 两区选择 + 写标题**。
3. 回归：`test-agent-parity.ps1`（舱内不得写死 grok / WZ_Skill）、`test-escape-hatch.ps1`（必须有 LIST 区）、e2e、validate。手测：F8 选非缺省项目 + 非第三列 Agent，页签必须是 `该项目 | 该 Agent`。

## 8. 验收句（用户可见）

- F8 先看到项目列表，再看到 Agent 列表（或因只有一项而跳过）。
- 选 Kimi 后页签是 `WZ_Skill | Kimi`（或所选项目名），**不是** desk-roots 里绑的 Agy。
- 没装 Grok 的机器，F8 仍能开出已装的那一家。
- Init 正常开聊的页签行为不回退。
