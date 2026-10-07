# -*- coding: utf-8 -*-
"""
微信公众号文章抓取工具：输入链接 → 输出本地 Markdown（图片本地化），供 agent 直接阅读。

用法:
    python wechat_reader.py <文章URL> [-o 输出目录] [--headed]

原理:
    使用真实 Chrome + 持久化浏览器档案（_wx_profile/）访问文章页。
    首次或被风控拦截时自动切换有头模式，人工完成一次"环境异常"验证后，
    会话会保存在档案中，后续抓取通常无需再验证。
"""
import argparse
import hashlib
import re
import sys
from datetime import datetime
from pathlib import Path

import requests
from markdownify import markdownify as md
from playwright.sync_api import sync_playwright

PROFILE_DIR = Path(__file__).parent / "_wx_profile"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")


def fetch_article(url: str, headless: bool, timeout_ms: int, img_dir: Path):
    """返回 (meta, 正文HTML)；被拦截或失败返回 None。图片已下载到 img_dir 并改写为本地路径。"""
    with sync_playwright() as p:
        ctx = p.chromium.launch_persistent_context(
            user_data_dir=str(PROFILE_DIR),
            channel="chrome",
            headless=headless,
            viewport={"width": 1280, "height": 900},
            locale="zh-CN",
        )
        try:
            page = ctx.pages[0] if ctx.pages else ctx.new_page()
            page.goto(url, wait_until="domcontentloaded", timeout=60000)
            page.wait_for_selector("#js_content", timeout=timeout_ms)
            page.wait_for_timeout(1500)  # 等懒加载/JS 稳定
            try:  # 公众号名称（新旧模板）是异步渲染的，单独再等一会儿
                page.wait_for_selector('#js_name, .wx_follow_nickname_con', timeout=5000)
            except Exception:
                pass

            meta = page.evaluate("""() => {
                const pick = s => (document.querySelector(s)?.textContent || '').trim();
                return {
                    title: pick('#activity-name')
                           || document.querySelector('meta[property="og:title"]')?.content || '',
                    account: pick('#js_name') || pick('.wx_follow_nickname_con')
                             || String(window.nickname || '')
                             || pick('.rich_media_meta_nickname') || '',
                    author: pick('#js_author_name') || String(window.author || '')
                            || document.querySelector('meta[name="author"]')?.content || '',
                    ct: String(window.ct || ''),
                };
            }""")
            # 还原懒加载图片的真实地址
            page.evaluate("""() => {
                document.querySelectorAll('#js_content img').forEach(img => {
                    const ds = img.getAttribute('data-src');
                    if (ds) img.setAttribute('src', ds);
                    img.removeAttribute('data-src');
                });
            }""")
            # 图片本地化：通过 DOM 属性收集与改写，不用正则碰 HTML 字符串
            # （正则会被 data-croporisrc 这类属性名截获，且处理不了 &amp; 实体编码）
            srcs = page.evaluate(
                "() => Array.from(document.querySelectorAll('#js_content img')).map(i => i.src)")
            mapping = download_images(srcs, img_dir)
            if mapping:
                page.evaluate("""mapping => {
                    document.querySelectorAll('#js_content img').forEach(img => {
                        const local = mapping[img.src];
                        if (local) img.setAttribute('src', local);
                    });
                }""", mapping)
            html = page.evaluate("() => document.querySelector('#js_content').innerHTML")
            return meta, html
        except Exception:
            return None
        finally:
            ctx.close()


def guess_ext(src: str, content_type: str) -> str:
    m = re.search(r'wx_fmt=(\w+)', src)
    fmt = (m.group(1) if m else '').lower()
    table = {'jpeg': '.jpg', 'jpg': '.jpg', 'png': '.png', 'gif': '.gif',
             'webp': '.webp', 'svg': '.svg', 'bmp': '.bmp'}
    if fmt in table:
        return table[fmt]
    ct = (content_type or '').lower()
    for k, v in [('jpeg', '.jpg'), ('png', '.png'), ('gif', '.gif'),
                 ('webp', '.webp'), ('svg', '.svg')]:
        if k in ct:
            return v
    return '.jpg'


def download_images(srcs, img_dir: Path) -> dict:
    """下载正文图片到本地（微信图片有防盗链且会过期，必须本地化），返回 {远程URL: 本地相对路径}。"""
    headers = {"Referer": "https://mp.weixin.qq.com/", "User-Agent": UA}
    mapping = {}
    for src in sorted(set(srcs)):
        if not src.startswith("http"):
            continue
        try:
            r = requests.get(src, headers=headers, timeout=30)
            r.raise_for_status()
            fname = hashlib.md5(src.encode()).hexdigest()[:12] + guess_ext(src, r.headers.get("Content-Type", ""))
            (img_dir / fname).write_bytes(r.content)
            mapping[src] = f"images/{fname}"
        except Exception as e:
            print(f"  [warn] 图片下载失败 {src[:90]}: {e}")
    return mapping


def sanitize(name: str) -> str:
    return re.sub(r'[\\/:*?"<>|\r\n]+', '', name).strip()[:60] or "untitled"


def main():
    ap = argparse.ArgumentParser(description="抓取微信公众号文章为 Markdown")
    ap.add_argument("url", help="公众号文章链接")
    ap.add_argument("-o", "--out", default="公众号文章", help="输出目录")
    ap.add_argument("--headed", action="store_true", help="直接使用有头浏览器（便于手动过验证）")
    args = ap.parse_args()

    out = Path(args.out)
    img_dir = out / "images"
    out.mkdir(parents=True, exist_ok=True)
    img_dir.mkdir(exist_ok=True)

    result = None if args.headed else fetch_article(args.url, headless=True, timeout_ms=15000, img_dir=img_dir)
    if result is None:
        print("[*] 快速模式未取到正文（可能被风控），打开浏览器窗口，如需验证请手动完成...")
        result = fetch_article(args.url, headless=False, timeout_ms=180000, img_dir=img_dir)
    if result is None:
        sys.exit("[x] 抓取失败：未获取到正文内容")

    meta, html = result
    body = md(html, heading_style="ATX", bullets="-").strip()
    if len(body) < 200:
        sys.exit(f"[x] 正文提取异常：仅获取到 {len(body)} 字符，可能被软风控或模板变更，请用 --headed 检查页面")

    pub = ""
    if meta["ct"].isdigit():
        pub = datetime.fromtimestamp(int(meta["ct"])).strftime("%Y-%m-%d")
    fetched = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    frontmatter = "\n".join([
        "---",
        f'title: "{meta["title"].replace(chr(34), chr(39))}"',
        f'account: "{meta["account"]}"',
        f'author: "{meta["author"].replace(chr(34), chr(39))}"',
        f"publish_date: {pub}",
        f"source: {args.url}",
        f"fetched_at: {fetched}",
        "---", "",
    ])

    fname = f"{pub + '-' if pub else ''}{sanitize(meta['title'])}.md"
    fpath = out / fname
    fpath.write_text(frontmatter + body + "\n", encoding="utf-8")
    print(f"[√] 已保存: {fpath}")
    print(f"    公众号: {meta['account']} | 作者: {meta['author'] or '-'} | 发布: {pub or '-'}")


if __name__ == "__main__":
    main()
