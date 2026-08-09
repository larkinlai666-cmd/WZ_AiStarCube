# WezTerm 配置加载安全契约（防「整份个性化失效」）

## 事故原貌（已发生 · 2026-08-09）

| 项 | 内容 |
|----|------|
| **现象** | 启动/重载后 WezTerm 像出厂默认：无 Init、无 F6–F9、无路径槽、无 AI STAR CUBE 顶栏 |
| **报错** | `attempt to yield across a C-call boundary` |
| **根因** | `live-workbench/workbench/launch.lua` 在 **`require()` / config 求值阶段** 调用了 `wezterm.run_child_process({ "where.exe", "grok" })` |
| **机制** | WezTerm 在加载配置时处于不可 yield 的 C 边界；`run_child_process` 会 yield → 异常 → **整份 user config 被丢弃**，回退内置默认 |
| **数据是否丢** | **否**。`desk-roots.tsv`、sessions、workbench 文件都在；只是 **未加载** |

## 三方版本对照（分析时点）

| 位置 | 路径 | `resolve_grok` 是否安全 | 与谁一致 |
|------|------|-------------------------|----------|
| **本机运行时** | `%USERPROFILE%\.config\wezterm\` | ✅ `io.open` + `PATH` 扫描 | = 本仓 working tree `live-workbench/` |
| **本仓未提交工作区** | `live-workbench/` | ✅ 已修 | = 本机 live |
| **GitHub `origin/main`** | 公开仓快照 | ❌ **仍含 `where.exe` + `run_child_process`** | = 本仓 **已提交 HEAD**（修复未 push） |

**结论：**  
线上公开安装路径（`Install-WZ.ps1` → clone `origin/main`）在修复推送前会 **复现整配置失效**。本机之所以能用，是因为 live 目录里已是未推送的修复版。

## 允许 / 禁止（硬规则）

### 配置加载期（`wezterm.lua` require 链、模块顶层、`M.xxx = resolve()`）

| 允许 | 禁止 |
|------|------|
| `io.open` / 读文件是否存在 | `wezterm.run_child_process` |
| `os.getenv("PATH")` 拆目录拼路径 | `where.exe` / 任意外部进程 |
| 纯 Lua 字符串与表操作 | 任何会 yield 的 API |
| `pcall(require, …)` 软失败 | 未捕获的 `error()` 拖垮整树 |

### 运行期（按键回调、`update-status`、用户动作）

| 允许（建议 `pcall`） | 注意 |
|----------------------|------|
| `run_child_process`（F9 扫目录、`wezterm cli list` 等） | 失败要降级，不能假定成功 |
| `window:toast_notification` | 需要有效 window |
| 写 `desk-roots.tsv` | 父目录应在安装时已创建；写失败则 toast，勿在加载期 mkdir spawn |

## 多层防护（已落地 / 应保持）

1. **`launch.lua`**：`resolve_grok_exe` 仅 `io.open` + env PATH；注释写明 MUST NOT spawn。  
2. **`wezterm.lua`**：`package.loaded` 清理 workbench.*；`safe_require` / `safe_apply`（单模块失败不空白整窗）。  
3. **`scripts/wezterm_load_guard.ps1`**：静态扫描加载期危险模式；推送/安装前应 exit 0。  
4. **事件回调 `STATUS_GEN`**：降低热重载堆叠旧 handler 的「假修复」。  
5. **公开仓同步纪律**：live 修复必须进入 `live-workbench/` **并 push**，否则第三方 `Install-WZ` 仍装到炸弹版。

## 验收命令

```powershell
# 本机 live
powershell -ExecutionPolicy Bypass -File .\scripts\wezterm_load_guard.ps1 -WorkbenchRoot "$env:USERPROFILE\.config\wezterm"

# 仓库快照
powershell -ExecutionPolicy Bypass -File .\scripts\wezterm_load_guard.ps1 -WorkbenchRoot .\live-workbench
```

## Agent / 开发者检查清单（改 workbench 前）

- [ ] 新增代码是否在 **模块顶层** 或 `require` 时执行？若是 → 禁止 spawn / 网络 / 重 IO。  
- [ ] `M.foo = bar()` 这种「加载即跑」是否只做纯计算？  
- [ ] 改完 `workbench/*.lua` 是否 bump 了 `wezterm.lua` 的 `reload-bump` 或触碰主文件？  
- [ ] 是否跑过 `wezterm_load_guard.ps1`？  
- [ ] 是否同步了 `~/.config/wezterm` **与** `live-workbench/`？  
- [ ] 是否准备 push，避免 GitHub 落后于本机？  

## 相关文档

- `docs/PROGRESS_SNAPSHOT.md` — 事故条目  
- `live-workbench/INSTALL.md` — 安装  
- `docs/PORTABILITY.md` — 第三方可移植性  
