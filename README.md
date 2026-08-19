# WZ_AiStarCube_win

> 纯 Windows 平台的 WezTerm AI Agent 工作台。macOS、Linux 与 WSL 宿主不在支持范围内。

WZ_AiStarCube_win 把项目路径、终端任务和本机 AI Agent 放进同一套轻量工作流。设计遵循四项原则：轻量、稳定、高性能、Agent 全面兼容平权。

## 当前能力

- 开放式发现本机 Agent：合并当前进程与最新持久化 PATH，从 npm、Python、可执行文件静态能力元数据、`*.wz-agent.json` 与用户本地注册表收集候选，不维护产品白名单，也不执行候选程序做探测。
- Agent 与 CLI 合并为一个选择：每个发现结果同时携带显示名称和准确启动路径。
- 4 步新建流程：项目名 → 位置 → Agent → 确认；手填父目录只保留 `[0]`。
- 动态 Agent 一律进入同一选择器、启动路由和状态识别；没有产品专属主入口。
- 项目路径门禁阻止用户目录、系统目录、临时目录、隐藏工具目录和盘符根目录成为正式项目。
- 文件与会话读取使用一个全局真实进度轴；原生 Agent `.exe` 直 spawn，启动黑屏属于 Agent 冷启动，工作台不再画封面猫或伪造百分比。
- Codex 续聊会比较当前 CLI 与会话写入版本；旧 CLI 不再打开必然失败的页签，而是在 Init 原页提示升级并允许按 `r` 后重试。
- 配置、项目绑定和本地清单采用同目录临时文件、校验与原子替换，降低断电或并发写入造成的损坏风险。

## 平台与依赖

- Windows 10/11
- Windows PowerShell 5.1 或 PowerShell 7+
- WezTerm
- 至少一个正确安装、可由本机元数据识别的 AI Agent CLI

安装器会在非 Windows 主机上直接停止。网络只在克隆仓库或安装依赖时需要。

## 安装

```powershell
git clone https://github.com/larkinlai666-cmd/WZ_AiStarCube_win.git
cd WZ_AiStarCube_win
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1
```

可选：指定新项目默认父目录。

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -ProjectsRoot D:\MyProjects
```

安装器会备份现有 `%USERPROFILE%\.config\wezterm`、复制并校验工作台文件、保留已有本地项目清单，然后绑定当前仓库（可用 `-SkipBindRepo` 跳过）。安装后重启 WezTerm。

只做环境诊断：

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -DoctorOnly
```

## Agent 发现

重新执行安装器或在 Init 面板任一步骤按 `r` 会重新探测。探测器直接重读用户/系统持久化 PATH，所以安装器刚写入 PATH 后不必重启整个 WezTerm。发现逻辑是能力与元数据驱动的，不要求 Agent 属于某个已知品牌。

自动来源包括：

- 当前进程 PATH 与最新用户/系统持久化 PATH 中的可执行入口
- npm 全局包的 `package.json` / `bin`
- Python `console_scripts` / 包元数据
- 独立用户级 `app\bin` EXE 的版本资源或静态 AI/coding-agent 能力声明（带文件指纹缓存，不启动 EXE）
- `*.wz-agent.json` 显式清单

无法自描述的独立二进制可以写入私有文件：

```text
%USERPROFILE%\.config\wezterm\workbench\agent-registry.local.tsv
```

格式为 `id<TAB>label<TAB>command-or-absolute-path`；第三列可用 `|` 分隔多个入口别名。该文件不会进入仓库。发现器最终解析并记录准确路径，同时执行别名折叠、去重、控制字符清理、元数据读取限额和静态扫描总量限制。

## 使用

| 按键 | 作用 |
|---|---|
| `F1` | 帮助卡 |
| `F2` | 保留给 Agent |
| `F3` | 新建项目向导 |
| `F4` | 关闭当前窗格 |
| `F5` | 重载 WezTerm 配置 |
| `F6` | 打开三栏 Agent 工作台 |
| `F7` | 打开项目文件侧栏 |
| `F8` | 逃生舱（安装根 `repair\`，等权选 Agent；Init 坏了按这个） |
| `Ctrl+Shift+R` | 备用配置重载 |

工作台不绑定 Leader。Init 面板可选择任务、创建项目、刷新 Agent 清单或退出。Init 不可用时按 F8，或运行 `~\.config\wezterm\workbench\wz.cmd repair`。

在任意项目目录中打开：

```powershell
powershell -ExecutionPolicy Bypass -File .\open-project.ps1
```

## 验证

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\readiness_check.ps1 -Verified
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -DoctorOnly
```

## 仓库结构

```text
WZ_AiStarCube_win/
├── Install-WZ.ps1             Windows 安装器与 Doctor
├── open-project.ps1           从正确项目路径打开工作台
├── live-workbench/            可安装的 WezTerm 配置
│   └── workbench/
│       ├── agent-discovery.ps1
│       ├── bootstrap.ps1
│       ├── desk.lua
│       ├── launch.lua
│       └── ...
├── scripts/                   验证与恢复脚本
├── docs/MAIN.md               行为契约
├── DECISIONS.md               决策记录
└── PROJECT_STATE.md           当前状态
```

## 隐私与边界

作者的项目清单、收藏、会话记录、账户信息和本地 Agent 注册表不会随仓库发布。项目只提供 Windows 工作流壳与检测机制，不捆绑任何 Agent、凭据或聊天历史。

License 尚未单独声明；在此之前，仓库内容仅供公开查看、备份与协作参考。
