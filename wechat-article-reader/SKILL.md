---
name: wechat-article-reader
description: 抓取微信公众号文章并保存为本地 Markdown（含图片本地化），使其对 agent 可读。当用户提供 mp.weixin.qq.com 链接、想阅读/保存/归档公众号文章时使用。
---

# 微信公众号文章抓取

微信有反爬机制，直接访问文章 URL 会返回"环境异常"验证页，拿不到正文。本 skill 用真实 Chrome 加持久化浏览器档案绕过检测，把文章转成 agent 可读的 Markdown 文件。

## 使用方法

在工作区根目录运行：

```powershell
uv run --project <本skill目录> <本skill目录>\scripts\wechat_reader.py "<文章URL>"
```

参数：

- `-o <目录>`：输出目录，相对于当前工作目录，默认 `公众号文章/`
- `--headed`：直接用有头浏览器。首次使用或会话失效时用，方便手动过验证

首次运行前先在本 skill 目录执行 `uv sync`（直接 `uv run` 也会自动同步）。

## 工作流程

1. 先用无头模式快速抓取，15 秒内出结果。
2. 被风控拦截时自动弹出浏览器窗口，请用户手动完成一次滑块验证。会话保存在 `scripts/_wx_profile/`，之后长期免验证。
3. 抓取时会剔除非正文组件（赞赏弹窗、二维码弹窗、底部元信息栏），并裁掉正文末尾的推广区（"好文推荐""会议推荐"之类）。每篇文章输出一个 `.md`，头部 YAML frontmatter 记录标题、公众号、作者、发布日期、原文链接。图片下载到 `images/`，文中引用本地相对路径。

## 注意事项

- 微信图片有防盗链且会过期，脚本已做本地化，这一步不能省。
- 原文随时可能被删除，抓取即存档，不要只存链接。
- 抓取完成后直接 read 生成的 `.md` 文件阅读全文。
- 批量抓取时链接间留 10 秒以上间隔，避免触发风控。
- 依赖 `playwright`、`markdownify`、`requests`，由 uv 管理（见 `pyproject.toml` 和 `uv.lock`）。本机需装有 Chrome。
