# 个人 Skill 仓库

个人维护的 agent skill 仓库。每个 skill 解决一类具体问题，可以注册或复制到任意 agent 的 skills 目录中使用。

## 目录结构

```
skills/
├── README.md            本文件，仓库规范
├── AGENTS.md            agent 行为准则
└── <skill-name>/
    ├── SKILL.md         给 agent 看：触发时机和用法
    ├── README.md        给人看：安装、排错、已知限制
    └── scripts/         支撑脚本（如有）
```

## Skill 清单

| Skill | 作用 | 文档 |
|-------|------|------|
| wechat-article-reader | 抓取微信公众号文章为本地 Markdown，方便 agent 阅读 | [SKILL](wechat-article-reader/SKILL.md) / [README](wechat-article-reader/README.md) |

## 新增 Skill 规范

1. 目录名用 kebab-case，与 SKILL.md 里的 name 一致。
2. SKILL.md 给 agent 看。frontmatter 的 description 要写清什么时候触发，agent 靠它决定加不加载。
3. README.md 给人看，包含环境要求、快速开始、常见问题。常见问题的写法：能解决的给出具体做法，解决不了的就写明暂未解决和原因，不要含糊带过。
4. 脚本放在 scripts/ 下，路径相对化，不依赖绝对路径。
5. 依赖和环境要求写进 README.md。Python 项目用 uv 管理，提交 pyproject.toml 和 uv.lock。
6. 至少跑通一个真实用例再提交。

## 使用方式

本工作区内直接按 SKILL.md 的说明运行脚本。在其他工作区使用时，把对应 skill 目录整个复制到对方的 skills 目录（比如 `~/.claude/skills/`），或在 agent 配置里注册本仓库路径。
