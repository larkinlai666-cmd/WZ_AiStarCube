# AI STAR CUBE · WezTerm

面向 **Grok / Kimi / Codex** 等无桌面客户端 AI CLI 的专业工作台（**AI STAR CUBE**）。

## 安装位置

```
%USERPROFILE%\.wezterm.lua
%USERPROFILE%\.config\wezterm\
  wezterm.lua
  README.md
  workbench\   (options / keys / layouts / launch / status / …)
```

改完后一般会自动热重载（`automatically_reload_config`）。手动重载请用：

| 方式 | 按键 | 说明 |
|------|------|------|
| **最省事** | **`Ctrl+F5`** | 不依赖 Leader；成功右上 toast「配置已重载」 |
| 常用 | **`Ctrl+Shift+R`** / **`Ctrl+Alt+R`** | 同上 |
| Leader | **`Alt+z`** 再 **`'`** | 新 Leader（旧 `Alt+;` 在中文 IME 下经常完全无效） |
| 彻底 | 退出并重开 WezTerm | 若快捷键仍无 toast，用这个 |

说明：
- **`Alt+; '` 请停用**——Leader 进不去时后续键全废，看起来像「没反应」。
- 自动热重载**只监视** `wezterm.lua`，改 `workbench\*.lua` 后必须手动重载一次。
- 重载成功标志：toast「配置已重载」，顶栏变为 **`本页签:…`**（不再是 `WS:`/`DESK:`）。

## 任务初始化面板（冷启动 + 新标签统一）

**同一套面板**，不是只在打开 WezTerm 时出现一次：

| 入口 | 结果 |
|------|------|
| 冷启动 WezTerm | 初始化表格面板 |
| 标签栏 **+** / **Ctrl+Shift+T** / **Alt+z 然后 t** | 新标签 = 同一面板 |
| **F3** | 再开一页面板 |
| **Ctrl+Alt+T** 或 **Alt+z 然后 \\** | 纯 PowerShell（不要面板时） |
| `workbench/no-bootstrap` 空文件 | 恢复「新标签=空白 PS」 |

| 列 | 含义（`summary.json`） |
|----|------------------------|
| 最近活跃 | `last_active_at` |
| 项目 | 工作目录名 |
| 模型 | `current_model_id` |
| Agent | `agent_name` |
| 消息 | `num_chat_messages` |
| 分支 | `head_branch` |
| 标题 | `generated_title` |

面板 LIST（终端真表，按显示宽度对齐）：

| 列 | 说明 |
|----|------|
| # | 序号 |
| DateTime | **始终带日期**（`MM-dd HH:mm`） |
| Project | 项目名 |
| Model | AI 模型；**非 AI / 无模型则为空** |
| Msgs | 消息数 |
| Branch | git 分支 |
| Title | 会话标题 |

默认过滤：**无 title 不进表**；**msgs &lt; 100 不进表**；最多 **15** 条。  
**a** 切换放宽视图。操作：j/k、Enter、n、i、d、q。  


统一命令（任意终端）：

```powershell
powershell -NoLogo -NoExit -ExecutionPolicy Bypass -File $env:USERPROFILE\.config\wezterm\workbench\bootstrap.ps1
```

---

## 页签优先（叠窗问题修复）

**症状：** 新开的会话不像顶部页签并排，而是整窗盖住旧窗；关掉前面的窗口才看到后面的。

**原因：**
1. `Start-Process grok.exe` 会开 **独立 OS 窗口**，不是 WezTerm 页签。
2. 再次启动 `wezterm` 默认也可能新开 **第二个最大化 GUI**，叠在第一个上面。
3. 旧版 F9 使用 `SwitchToWorkspace`，会换掉整组页签（其它工作区的页签不在当前栏显示）。

**现策略：**
- `prefer_to_spawn_tabs = true`：二次启动优先进现有窗口的页签。
- `hide_tab_bar_if_only_one_tab = false`：始终显示顶栏。
- F9 / F6：在 **当前窗口 spawn 新页签**，不再用工作区切换藏页签。
- 打开项目脚本：`wezterm cli spawn` / `wezterm start --new-tab`，禁止裸 `Start-Process` 启动 agent CLI。

验证：按 **F9** 选一个目录后，顶栏应出现新页签且旧页签仍在。

## 快捷键作用域（先看）

| 问题 | 答案 |
|------|------|
| 是不是系统全局热键？ | **不是。** WezTerm 绑定只在 **本窗口聚焦** 时生效，不会 `RegisterHotKey` 抢全桌面。 |
| 切到浏览器 / 资源管理器时？ | F7/F9/F6 等 **不会触发** 工作台动作；各软件用自己的键。 |
| 如何减少冲突？ | ① 窗口级绑定（已满足）② 不绑系统/Grok 常用键 ③ Leader 用 **`Alt+z`**（勿用 `Ctrl+;` / 勿依赖旧 `Alt+;`） |
| 未绑定的键去哪？ | **原样进入终端**（例如 **F2 → agent TUI（Grok）设置**） |

详细审计表见下方「冲突审计」。

---

## 设计原则（中文输入友好）

1. **核心快捷键不要求 Shift / 大写字母**  
2. **不用 `Ctrl+Shift+字母` 当地板油**（输入法常抢）  
3. **直达用 F 键**，并避开 F1/F2/F5/F10/F12  
4. **可鼠标替代的就不绑**（切窗格 → 鼠标点）  
5. **不与 agent TUI 抢** `F2`、`Ctrl+;`（如 Grok 的设置 / 提示队列）  

---

## 任务关系模型

| 顶栏 | 示例 | 含义 |
|------|--------|------|
| **本页签:名字** | `本页签:WZ_Skill` | **当前标签页** 的项目（切换标签会变） |
| **路径** | `G:\GrokProject\WZ_Skill` | 该页签任务根（F6/F7/agent 绑定处） |
| **本窗格在项目内** | 绿 / 橙 | 焦点窗格是否在该页签项目树下 |
| **所在**（右） | `所在:…\docs` | 焦点窗格真实 cwd |

- 设计目的：多标签多项目时，一眼看到 **当前页签** 在干什么（以前误绑整窗 Workspace，三个标签显示同一个错名字）。
- 不能点击（WezTerm 状态栏限制）；动作用 **F9** 开项目、**F7** 侧栏。
- **不想看可以关**：`Alt+z` 然后 `Shift+H` 切换显示；关掉后只剩 ★ 与右侧信息。

绑定表：`workbench\desk-roots.tsv`（可选第三列 `agent`，D-004）。项目身份文件：`<项目根>\.wz-project`。

### 项目名 / 项目路径（写死规则 · D-003）

| 概念 | 定义 | 不是什么 |
|------|------|----------|
| **项目名** | `desk-roots` 左列（创建向导里起的绑定名） | Grok 会话标题、cwd 末级名、`home` |
| **项目路径** | `desk-roots` 右列绝对路径（创建时冻结） | 会话里 `cd` 后的临时目录 |
| **弱路径** | home / Desktop / Documents 根 / Downloads / AppData / Temp… | **永不当** 正式 TASK |

门禁：正式会话必须落在强项目路径（grok 用 `grok --cwd <强项目路径>`；kimi/codex 无统一 `--cwd`，靠进程 cwd 定身份，codex 亦可 `-C <DIR>`）；Init 里 SYS/home 行不能 Enter 开聊；新建用 `c` 向导一次写死。

### 多模型接手（D-004）

| 项 | 约定 |
|----|------|
| 默认 agent | `desk-roots.tsv` 可选**第三列** `agent`（`grok` / `kimi` / `codex`，三者平权）；无第三列时按已安装顺序解析 grok → kimi → codex 取第一个，grok 缺失也能正常起 kimi/codex；旧两行格式照常工作 |
| **kimi 启动** | **无 `--cwd`**：靠进程 cwd 定身份（`wezterm cli spawn --cwd <path> -- kimi`）；同模型续接手 `kimi --continue` |
| **codex 启动** | 有 `-C/--cd <DIR>`，但工作台统一用进程 cwd 定身份；续接手 `codex resume --last` |
| F6 三栏桌 | 按当前任务第三列启动对应 agent；无第三列按默认解析顺序（grok → kimi → codex 取第一个已安装） |
| 顶栏页签 | 项目名旁显示当前 agent（Grok / Kimi / Codex） |
| 新建向导 | F3 / Init `c` 第 4 步选默认 agent，**回车 = 默认解析**（grok → kimi → codex 取第一个已安装） |
| `open-project.ps1` | `-Agent <grok|kimi|codex>`；缺省 = desk-roots 第三列 → 已安装顺序取第一个 |

### 项目区选定 / 快捷切换（最重要）

把「项目」想成：**一个项目名 + 一条写死的项目路径**。

| 你想做什么 | 按什么 | 你会看到什么 |
|------------|--------|----------------|
| **选一个项目并进入** | **`F9`**（备用：`Alt+z` 再 `.`） | 弹出列表 → ↑↓ → **Enter** → 状态栏 `WS:`/`DESK:` 变了 |
| **在已打开的项目之间跳** | **`Alt+z` 再 `j`** | 工作区列表（只含已经进过的任务区） |
| **进项目后开 AI 对话桌** | **`F6`** | agent + Shell + 监视，都在当前 DESK |
| **看项目文件** | **先点 agent 窗格，再 `F7`** | 左侧 Explorer **严格绑当前对话 cwd/DESK**；单击路径用默认程序打开 |

列表前缀：`[任务]` 已绑定 · `[收藏]` · `[固定]` · 最底可「扫描更多」或「跳工作区」。

若 **F9 完全没反应**：① 点一下 WezTerm 窗口确认聚焦 ② 笔记本试 **`Fn+F9`** ③ 改用 **`Alt+z` → `.`**（与 F9 相同）④ 右下角应闪 toast「项目选择 F9」。

---

## 日常只需记这些

### 一键直达（F 键）

| 键 | 作用 |
|----|------|
| **`F7`** | 左侧 Explorer（绑 **DESK**） |
| **`F9`** | **选项目 / 进任务区**（弹列表） |
| **`F4`** | 关闭当前窗格 |
| **`F6`** | 标准三栏 AI 工作台 |
| **`F8`** | 快捷键速查面板（开关） |
| `F11` | 全屏 |

### Leader = **`Alt+z`** 然后小写

1. 按住 **左 Alt**，点 **`z`**，松开  
2. 状态栏出现 **`LEADER`**（若从不出现：勿再用 `Alt+;`，改用 F 键 / `Ctrl+F5`）  
3. 再按小写键  

| 键 | 作用 |
|----|------|
| `h` | 速查（同 F8） |
| `e` | Explorer（同 F7） |
| `.` | 选项目（同 F9） |
| `j` | **跳已打开的任务工作区** |
| `,` | 选项目并开三栏 |
| `a` / `b` | 新开三栏 / 原地三栏 |
| `d` `r` `g` `c` | 双 AI / Review / Grok / Codex |
| `x` | 关窗格（同 F4） |
| `v` / `s` / `z` | 分屏 / 放大 |
| `t` `w` `n` `[` `1–9` | 标签 |
| `p` `m` `` ` `` `/` | 面板 / 启动器 / 搜快捷键 |
| `'` | 重载配置 |
| `\` | 新 PowerShell 标签 |

### 刻意不绑

| 键 | 原因 |
|----|------|
| `F1` | Windows 帮助常吞键 |
| `F2` | **交给 agent TUI**（Grok 的设置键） |
| `F5` | 刷新肌肉记忆 |
| `F10` | 菜单焦点 |
| `F12` | 开发者工具肌肉记忆 |
| `Ctrl+;` | **交给 agent TUI**（Grok 的提示队列；故 Leader 改为 **Alt+z**） |

---

## 冲突审计（本机 + 设计）

| 键 / 组合 | 系统或其它软件 | 旧工作台 | 现策略 |
|-----------|----------------|----------|--------|
| F1 | Windows 帮助 | 曾作速查 | **不绑** |
| F2 | 资源管理器重命名；**agent TUI（Grok）设置** | Explorer | **不绑 → 留给 agent TUI** |
| F3 | 资源管理器搜索 | 项目选择 | 改 **F9** |
| F4 | 较少（注意不是 Alt+F4） | 关窗格 | **保留**（仅 WezTerm 聚焦） |
| F5 | 刷新 | — | **不绑** |
| F6 | 部分对话框切焦点 | 三栏桌 | **保留** |
| F7 / F8 / F9 | 占用少 | — | **核心直达** |
| F11 | 全屏惯例 | 全屏 | **保留**（窗口级） |
| Ctrl+; | **agent TUI（Grok）队列** | Leader | Leader 改 **Alt+z** |
| Alt+; | 中文 IME 常无 LEADER | 旧 Leader | **弃用为 Primary**；少量兼容 chord |
| Ctrl+Shift+* | 中文输入法 | 已废弃 | 继续不用 |
| Ctrl+Alt+* | 驱动 / AltGr | 已废弃 | 继续不用 |

本机进程抽查：未发现 PowerToys / AutoHotkey 等全局热键进程。若你之后安装全局启动器，以它们的全局表为准。

---

## 30 秒上手

1. 重启或 **`Ctrl+F5`**（或 `Alt+z` → `'`）重载  
2. **`F8`** 打开速查  
3. **`F9`** 选项目 → **`F6`** 三栏 → **`F7`** 侧栏  
4. agent TUI 内（如 Grok）：`F2` 设置、`Ctrl+;` 队列 应可正常用  

---

## 故障排除

| 现象 | 处理 |
|------|------|
| 还在按 F2/F3 开侧栏/项目 | 已改 **F7 / F9**；F2 留给 agent TUI（Grok） |
| 还在按 Ctrl+; / Alt+; 当 Leader | 已改 **Alt+z**；Ctrl+; 留给 agent TUI（Grok） |
| Leader 无 LEADER 闪现 | 用 **左 Alt + z**；勿依赖 Alt+; |
| F 键无反应 | 先点击 WezTerm 窗口确认聚焦；笔记本 `Fn+Fx` |
| 配置报错 | `Ctrl+F5` 重载；或 `Alt+z` 再 `i` |

策略源码：`workbench/keys.lua` 文件头注释。
