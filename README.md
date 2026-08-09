# WZ_AiStarCube

**基于 WezTerm 的 AI Agent 终端工作台（AI STAR CUBE）** —— 目标是把「在终端里用 Grok / Codex 等 Agent 写项目」从单窗聊天，升级成**可切换项目、可对齐路径、可并行窗格**的高效工作流，并最终沉淀为可复用的 **Skill / 工作流**。

> 公开仓库名：**WZ_AiStarCube**  
> 产品族名（决策 D-001）：**WZ-AiWorkBench**  
> 体验品牌：**AI STAR CUBE**

---

## 核心意义（为什么做）

无桌面客户端的 AI CLI，默认往往是：

- 一个终端会话 = 一段聊天
- 会话「户籍」（进程 cwd）和真正项目目录容易脱节
- 侧栏、多项目、快捷键、续聊没有统一任务模型

**WZ_AiStarCube 要解决的是：**

> 在 **WezTerm** 上建立一套稳定的 **Agent 终端交互壳**，让「选项目 → 开对话 → 看文件 → 续任务」成为肌肉记忆，从而**大幅提升 AI Agent 终端式开发效率**。

当前策略（D-002）：

| 阶段 | 焦点 | 状态 |
|------|------|------|
| **1 · 工作台本体** | 把 live WezTerm 做到合用 | **当前主线** |
| **2 · 封装** | 再做成 Skill / 工作流协议 | 延后 |

PPS（个人项目状态协议）**只作过程工具**，不是本产品功能内容。

---

## 当前实际成果（截至 2026-08-09 快照）

### 1. Live WezTerm 工作台（主交付）

运行时配置快照在仓库：

```text
live-workbench/          ← 可安装的 WezTerm 配置快照
  wezterm.lua
  workbench/
    desk.lua             项目路径门禁 + 页签级 DESK
    bootstrap.ps1        任务 Init 面板（列表 / 新建向导）
    projects.lua         F9 选项目、F7 Explorer
    status.lua           左侧路径槽 + 页签标题
    layouts.lua          F6 三栏 AI 桌
    keys.lua             键位（F6–F9, Leader Alt+;）
    sidebar.ps1          左侧文件树
    launch.lua / resume.lua / options.lua / …
  INSTALL.md
```

安装说明见 [`live-workbench/INSTALL.md`](live-workbench/INSTALL.md)。

### 2. 任务模型（项目名 / 路径写死）

| 概念 | 定义 | 不是什么 |
|------|------|----------|
| **项目名** | `desk-roots.tsv` 左列 + `.wz-project` | Grok 会话标题、home |
| **项目路径** | 绝对路径，创建时冻结 | 会话内 `cd` 临时目录 |
| **会话 cwd** | Grok 启动 `--cwd` | 与路径槽不一致时需重开 |

**门禁（R1–R6 / D-003）：**

- 正式 Grok 必须 `grok --cwd <强项目路径>`
- home / Desktop / Documents 根 / Downloads / AppData 等**永不当正式项目**
- Init 新建向导一次写死：目录 + desk-roots + `.wz-project`
- 禁止「会话户籍在 home、内容却在聊项目」的散落

### 3. 交互面（效率点）

| 键 | 作用 |
|----|------|
| **F9** | 选项目 → 当前窗**新页签**（tabs-first，不藏旧页签） |
| **F6** | 三栏 AI 桌（Grok + Shell + 监视） |
| **F7** | 左侧 Explorer，绑当前任务根 |
| **F8** | 速查 |
| **Init** | 冷启动/新标签默认任务表：续聊 / `c` 新建 / `n` 同项目新会话 |
| 路径槽 | Wez 左侧全路径展示（与 Grok 顶栏应对齐） |

### 4. 工程侧

| 路径 | 作用 |
|------|------|
| `docs/MAIN.md` | 需求与行为契约 |
| `DECISIONS.md` | 权威 M/F/D（含 D-003 项目身份） |
| `PROJECT_STATE.md` / `CONTEXT.md` | 热状态与工作集 |
| `open-project.ps1` | 用正确 cwd 在 WezTerm **页签** 打开 Grok |
| `scripts/` | 恢复包 / 校验（PPS 过程脚本） |
| `skills/wz-skill/` | **占位**，封装阶段再写真正 Skill |

---

## 其他用户：一键获得同等工作流

**目标：** clone 后安装，得到与作者一致的 **工作台壳**（键位 / Init / 门禁 / F6–F9），而不是作者的私有项目列表或聊天记录。

```powershell
git clone https://github.com/larkinlai666-cmd/WZ_AiStarCube.git
cd WZ_AiStarCube
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1
# 可选：指定新建项目父目录
# powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -ProjectsRoot D:\MyProjects
```

然后 **重启 WezTerm**。验收与限制见 [`docs/PORTABILITY.md`](docs/PORTABILITY.md)。

| 你会得到 | 你不会得到 |
|----------|------------|
| 同样的 Init / 门禁 / F6–F9 / 路径冻结 | 作者的 desk-roots 项目清单 |
| 本仓自动绑成第一个 TASK（可 `-SkipBindRepo`） | 作者的 Grok 会话历史 |
| 新建向导可移植默认父目录 | macOS/Linux 一等支持（当前 Windows-first） |

前置：Windows + WezTerm + Grok Build CLI。

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -DoctorOnly
```

## 快速使用（已安装）

```powershell
# 用本仓正确 cwd 在 WezTerm 页签打开 Grok
powershell -ExecutionPolicy Bypass -File .\open-project.ps1

# 或任意项目
grok --cwd C:\path\to\your\project
```

恢复本仓工程上下文：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\resume_packet.ps1
```

---

## 仓库结构

```text
WZ_AiStarCube/
├── README.md                 # 本说明
├── docs/MAIN.md              # 主需求与契约
├── DECISIONS.md              # 权威决策
├── live-workbench/           # WezTerm / AI STAR CUBE 快照 ★
├── open-project.ps1
├── scripts/                  # 状态恢复与校验
├── skills/wz-skill/          # Skill 占位（未激活）
└── …
```

---

## 路线图（简）

1. **已完成（本快照）**：tabs-first 多项目、路径槽、Init 面板、门禁与项目名定义、创建路径冻结、Explorer 同根  
2. **进行中**：作者验收清单、边用边修工作台缺口  
3. **后续**：封装为 WZ-AiWorkBench Skill / 工作流；可选跨机安装与同步

---

## License

未单独声明前，默认仅作公开备份与协作参考；使用 live 配置请自担风险并先备份本机 `~/.config/wezterm`。

## 作者

开发与个人工作台迭代中。Issues / PR 欢迎，当前优先级仍是作者本机工作台合用度。
