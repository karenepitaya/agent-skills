# agent-constitution

编码 agent 的行为准则。核心很短，做某类任务时才读取对应的场景文件。

没有运行时依赖，全是 Markdown。

## 安装

把本目录整个复制，或用软链接放进 agent 的 skills 目录：

- Cursor：`~/.cursor/skills/`
- Claude：`~/.claude/skills/`

目录名保持 `agent-constitution`，与 [SKILL.md](SKILL.md) frontmatter 里的 `name` 一致。

## 按需加载

触发后始终读取 [SKILL.md](SKILL.md)。场景文件只在它的路由表点到时才读：

| 任务 | 读取 |
|------|------|
| 界面、页面、HTML、原型，以及幻灯片的像素 | [frontend.md](frontend.md)，再加上项目里的 `DESIGN.md`（没有就从 [DESIGN.template.md](DESIGN.template.md) 填一份） |
| 文档、报告、邮件、中文，以及幻灯片的文字 | [office.md](office.md) |
| API、数据库、服务 | [backend.md](backend.md) |
| 测试、验收 | [testing.md](testing.md) |
| 部署、环境、CI | [ops.md](ops.md) |

[problem-catalog.md](problem-catalog.md) 只在追溯某条规则为什么存在，或要改规则时打开。做任务时不读。

项目自己的 `AGENTS.md` 优先于本 skill。

## 已知限制

[backend.md](backend.md) 约 4.8KB，超过 3–4KB 的目标。里面 12 条规则各自保留了 why 和 test，再缩短会丢掉约束。
