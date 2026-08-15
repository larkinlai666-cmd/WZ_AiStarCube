# Windows portability and adversarial audit

WZ_AiStarCube_win 的可移植目标是：另一台 Windows 设备克隆并安装后，得到相同的工作台行为，而不是复制作者的私人项目、会话或账户。

macOS、Linux 和 WSL 宿主明确不受支持；安装器会在非 Windows 环境停止。

## 一条命令路径

```powershell
git clone https://github.com/larkinlai666-cmd/WZ_AiStarCube_win.git
cd WZ_AiStarCube_win
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1
```

随后重启 WezTerm。

## 对抗性检查矩阵

| 风险 | 当前防护 |
|---|---|
| 安装中断留下半份配置 | 同目录临时文件、SHA-256 校验、原子替换；安装前备份旧配置 |
| 重装覆盖私人项目清单 | 保留已存在的 `desk-roots.tsv`、收藏和本地 Agent 注册表 |
| 弱路径被绑定为正式项目 | 拒绝用户目录、常用用户文件夹、AppData、隐藏工具目录、系统/临时目录和盘符根目录 |
| Agent 类型写死 | PATH、npm、Python、清单和本地注册表均按元数据/能力发现，不以品牌白名单筛选 |
| 可执行路径被同名命令劫持 | 启动时使用发现记录中的准确绝对路径，并在生成窗格前再次验证 |
| 恶意或异常元数据 | 限制 JSON/文本读取大小，清除控制字符，限制字段长度，校验 ID 和可执行文件 |
| Agent 在选择后被卸载 | 启动前重新检查；失败时停止，不静默退回普通 shell |
| 猫猫进度先于真实读取完成 | 全部可计数读取共享一个总量；合并并发布结果后才到 100% |
| 外部进程时长未知 | 仅显示不定进度等待动画，不承诺百分比或虚假“完成” |
| desk roots 写入被打断 | 新文件落盘后才切换旧文件，并保留可恢复备份 |
| 个人数据进入仓库 | `.gitignore` 排除绑定、根目录、收藏、最近目录和本地 Agent 注册表 |

## 可移植与不可移植内容

| 随仓库提供 | 不随仓库提供 |
|---|---|
| WezTerm 配置与工作台模块 | 作者的项目清单与收藏 |
| Init、项目门禁、4 步创建和动态 Agent 选择 | Agent 凭据、账户和会话原文 |
| 快捷键、布局、侧栏与路径身份 | 私有 `agent-registry.local.tsv` |
| 开放发现机制与可选显式清单协议 | macOS/Linux 兼容层 |

## 验收

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\readiness_check.ps1 -Verified
powershell -ExecutionPolicy Bypass -File .\Install-WZ.ps1 -DoctorOnly
```

手工烟测：

1. WezTerm 打开后出现 Init 面板。
2. `r` 重新探测本机 Agent，新安装且能自描述的 Agent 出现在同一备选列表。
3. `c` 创建项目时只有 4 步，Agent/CLI 不分离，手填父目录只显示 `[0]`。
4. `F6` 只在已绑定的强项目路径上创建三栏。
5. `F7` 的文件根目录与任务路径一致。
