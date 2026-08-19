# F8 逃生舱

Init 炸掉时按 **F8**。

## 你怎么用

1. WezTerm 窗口是焦点，按 **F8**。
2. 进入安装根下的 `repair\`（不是当前项目，也不是 WZ_Skill 仓库）。
3. 本机 Agent 等权列出：一家直开，多家选号。页签为 `WZ_Repair | 你选的那一家`。
4. 命令行同一套：`workbench\wz.cmd doctor` / `report` / `repair`。
5. WezTerm 配置全挂：双击 `workbench\Escape-WZ.cmd`。

`repair\` 只记事故、只修安装树。每次进舱会在 `JOURNAL.md` 追加一条（时间、已装 Agent、加载/探测残片）。`wz report` 另存完整快照。重装不覆盖已有 `INCIDENT*.md` / `JOURNAL.md`。模块加载失败时 toast 会写「按 F8」。

## 为什么 cwd 在安装旁

WZ 是工作流产品。用户机器上的安装根是 `~\.config\wezterm\`。`repair\` 与 `workbench\` 并列，安装器只补模板，不删笔记。它不是 desk-roots 任务，不进 Init 列表。

## 页签

现场 Agent 写进标题。desk-roots 第三列只做日常任务缺省路由，不再把空闲壳显示成 Agy。
