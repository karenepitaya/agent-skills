# 个人 Skill 仓库

这个目录是个人维护的 agent skill 仓库。每个 skill 解决一类具体问题，可以被注册/复制到任意 agent 的 skills 目录中使用。

## 目录结构

```
skills/
├── README.md                   ← 本文件
└── <skill-name>/
    ├── SKILL.md                ← skill 定义（YAML frontmatter: name/description + 使用说明）
    └── scripts/                ← 支撑脚本（如有）
```

## Skill 清单

| Skill | 作用 |
|-------|------|
| [wechat-article-reader](wechat-article-reader/SKILL.md) | 抓取微信公众号文章为本地 Markdown，使私域内容对 agent 可读 |

## 新增 Skill 规范

1. 目录名用 kebab-case，与 `SKILL.md` 里的 `name` 一致
2. `SKILL.md` frontmatter 的 `description` 必须写清**什么时候触发**（ agent 据此决定是否加载）
3. 脚本放在 `scripts/` 下，路径相对化，不依赖绝对路径
4. 依赖和环境要求写在 SKILL.md 的"注意事项"里
5. 验证通过后再提交到本仓库（至少跑通一个真实用例）

## 使用方式

- **本工作区内**：直接按 SKILL.md 说明运行脚本
- **其他 agent / 工作区**：把对应 skill 目录整个复制到对方的 skills 目录（如 `~/.claude/skills/` 或项目的 `.skills/`），或在 agent 配置中注册本仓库路径
