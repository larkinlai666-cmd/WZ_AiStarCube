# WZ_AiStarCube_win live workbench

这是仓库中可安装的 WezTerm 配置快照，仅支持 Windows。

## 组成

- `wezterm.lua`：最小入口，加载 `workbench/` 模块。
- `workbench/agent-discovery.ps1`：开放式本机 Agent 探测；合并进程与持久化 PATH，静态识别缺少包清单的用户级独立 CLI，并缓存文件指纹；不使用产品白名单、不执行候选程序。
- `workbench/bootstrap.ps1`：Init 任务面板、4 步项目创建、会话索引与统一真实读取进度。
- Codex 专属续聊适配器会保留会话写入 CLI 版本；运行时更旧则留在 Init 提示升级，不产生失败页签。
- `workbench/desk.lua`：项目身份、路径门禁、动态 Agent 进程识别和安全绑定写入。
- `workbench/launch.lua`：按发现到的准确可执行路径启动 Agent。
- `workbench/layouts.lua`：受门禁保护的单窗格与三栏布局。
- `workbench/sidebar.ps1`：与当前任务根目录对齐的文件侧栏。

## 快捷键

| 按键 | 作用 |
|---|---|
| `F1` | 帮助 |
| `F2` | 留给 Agent |
| `F3` | 新建项目 |
| `F4` | 关闭窗格 |
| `F5` | 重载配置 |
| `F6` | 三栏 Agent 工作台 |
| `F7` | 文件侧栏 |
| `F8` | 逃生舱（`repair\`，等权选 Agent） |
| `Ctrl+Shift+R` | 备用重载 |

不设置 Leader。F8 是产品修理入口，不是日常任务。`workbench\wz.cmd doctor|report|repair` 与 F8 同一套。

## 进度语义

文件与会话候选先被枚举一次，再由一个全局计数器驱动猫猫进度动画；达到 100% 时，结果已经完成合并并发布给界面。外部 Agent 的真实就绪时间无法可靠查询：原生 `.exe` 直 spawn，启动黑屏是 Agent 自己的冷启动，不是工作台没做封面。

## 安装

优先从仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1
```

手动安装与本地 Agent 注册格式见 [INSTALL.md](INSTALL.md)。
