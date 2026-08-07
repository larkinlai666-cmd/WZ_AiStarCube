# WZ_Skill

**WezTerm（wz）通用 Agent Skill 项目**：强化 AI Agent 在 WezTerm / **AI STAR CUBE** 工作台上的交互体验与效率。

## 和 PPS 的关系（请先读）

**PPS 不是本产品的功能模块，也不是本仓要开发的内容。**

- PPS = 个人项目推进用的 **工作协议 + 脚本工具集**（有界恢复、权威 ID、工作集、收口验证）。
- 本仓 = **WZ Skill 产品**（WezTerm / AI 工作台 skill）。
- 两者 **内容不覆盖**；这里只是 **按 PPS 的工作逻辑** 管理状态（`PROJECT_STATE.md`、`DECISIONS.md`、`CONTEXT.md` 等）。
- PPS 工具集独立目录：`G:\GrokProject\PPS_SKILL`（需要升级协议时去那边，不要把 PPS 源码合进本仓当功能）。

## 当前入口

| 文件 | 作用 |
|---|---|
| `PROJECT_STATE.md` | 热状态 / 下一动作 |
| `CONTEXT.md` | 当前工作集（Read/Write/Verify） |
| `DECISIONS.md` | 生效权威 `M/F/D` |
| `docs/MAIN.md` | 当前主产物（需求与 skill 规格） |
| `PROJECT_MAP.md` | 组件导航 |
| `open-project.ps1` | 用正确 cwd 打开 Grok |

## 用正确根目录打开 Grok

当前聊天如果顶部仍是用户主目录，说明会话启动 cwd 不对。在本机执行：

```powershell
powershell -ExecutionPolicy Bypass -File G:\GrokProject\WZ_Skill\open-project.ps1
```

或：

```powershell
grok --cwd G:\GrokProject\WZ_Skill
```

## 恢复工作（PPS 逻辑）

```powershell
powershell -ExecutionPolicy Bypass -File scripts/resume_packet.ps1
```

只按恢复包里的 ID 与路径工作，不要整仓塞进上下文。

## 人话操作

- 「同步并继续」：安全拉远端后按 Workset 恢复。
- 「保存并同步」：写完、验证、提交、推送。
- 「这个定了」：把你明确批准的内容记成 `D-*` 并传播到成品。
