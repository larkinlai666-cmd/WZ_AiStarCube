# Live workbench installation

仅支持 Windows。优先使用仓库根目录安装器，它负责备份、校验、原子写入、空清单初始化和当前仓库绑定：

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1
```

## 手动安装

只有在无法运行安装器时才使用以下方式：

1. 安装 WezTerm、PowerShell 5.1+ 和至少一个能由元数据识别的 AI Agent CLI。
2. 备份 `%USERPROFILE%\.config\wezterm`。
3. 将 `live-workbench\wezterm.lua` 与整个 `live-workbench\workbench` 复制到 `%USERPROFILE%\.config\wezterm`。
4. 新建空的 `workbench\desk-roots.tsv`；不要把示例项目清单当作真实清单。
5. 重启 WezTerm，在 Init 中按 `c` 创建项目，或从项目目录运行 `open-project.ps1`。

## Agent 发现

发现器会扫描 PATH、npm/Python 包元数据、`*.wz-agent.json` 和安装目录中的可验证入口。没有可用元数据的独立二进制可写入：

```text
%USERPROFILE%\.config\wezterm\workbench\agent-registry.local.tsv
```

每行格式：

```text
id<TAB>label<TAB>C:\absolute\path\agent.exe
```

`id` 只能包含小写字母、数字、下划线和连字符。第三列也可填写 PATH 中的命令名，并用 `|` 提供多个入口别名；发现结果始终保存解析后的准确路径。修改后在 Init 面板按 `r` 重新发现。

## 可选环境变量

| 变量 | 作用 |
|---|---|
| `WZ_PROJECTS_ROOT` | Init 新建项目的默认父目录 |

## 不随安装迁移

- 原设备的项目清单、收藏和最近目录
- Agent 会话、账户或凭据
- 私有 `agent-registry.local.tsv`
- 任何非 Windows 运行时适配
