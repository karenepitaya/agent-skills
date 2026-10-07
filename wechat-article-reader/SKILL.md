---
name: wechat-article-reader
description: 抓取微信公众号文章并保存为本地 Markdown（含图片本地化），使其对 agent 可读。当用户提供 mp.weixin.qq.com 链接、想阅读/保存/归档公众号文章时使用。
---

# 微信公众号文章抓取

微信公众号有反爬机制（"环境异常"验证码拦截），agent 无法直接访问文章 URL。本 skill 用真实 Chrome + 持久化浏览器档案绕过检测，把文章转为 agent 可读的本地 Markdown。

## 使用方法

在工作区根目录运行：

```powershell
uv run --project <本skill目录> <本skill目录>\scripts\wechat_reader.py "<文章URL>"
```

可选参数：
- `-o <目录>`：输出目录（相对于当前工作目录），默认 `公众号文章/`
- `--headed`：直接使用有头浏览器（首次使用或会话失效需要手动过验证时用）

依赖由 `uv` 管理：首次运行前在本 skill 目录执行一次 `uv sync`（或直接 `uv run`，会自动同步）。

## 工作流程

1. 先用无头模式快速抓取（15 秒内出结果）
2. 若被风控拦截，自动弹出浏览器窗口，**提示用户手动完成一次滑块验证**；会话保存在 `scripts/_wx_profile/`，之后长期免验证
3. 输出：每篇文章一个 `.md`，头部 YAML frontmatter 记录标题/公众号/作者/发布日期/原文链接；图片下载到 `images/` 并在文中引用本地相对路径

## 注意事项

- 微信图片有防盗链且会过期，脚本已将图片本地化，**不要跳过这一步**
- 抓取即存档：原文随时可能被删除，不要只存链接
- 抓取到 Markdown 后，直接 read 该文件即可阅读全文
- 批量抓取请在链接间留出间隔（建议 ≥10 秒），避免触发风控
- 依赖：`playwright`、`markdownify`、`requests`，由 `uv` 管理（见 `pyproject.toml` / `uv.lock`），本机需装有 Chrome
