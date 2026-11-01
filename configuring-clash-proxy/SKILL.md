---
name: configuring-clash-proxy
description: Use when configuring or migrating Windows Clash Verge Rev/Mihomo, replacing a subscription, setting up domestic-direct/foreign-proxy routing, or making Clash TUN coexist with Tailscale.
---

# Configuring Clash Proxy

## Overview

以当前 Windows 环境为模板：Clash Verge Rev + Mihomo、`127.0.0.1:7897`、TUN、fake-ip、规则模式。订阅只提供节点；本地增强脚本统一生成节点组、DNS 和分流规则。不得复制旧节点凭据或记录订阅 URL。

## 一键配置

在管理员 PowerShell 中运行；路径先解析到本 skill 目录，不要假定它是当前目录：

```pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\scripts\Install-ClashProxy.ps1" -SubscriptionUrl "<用户提供的订阅链接>"
```

缺少订阅时向用户索取。脚本使用 winget 安装缺失的 Clash Verge Rev、安装缺失的服务、备份受管文件、下载并校验订阅、生成每小时自动更新的远程 profile，然后启动应用并检查 7897 端口。端口就绪后才修改系统代理；写入或启动失败会恢复受管文件。订阅 URL 不写入日志。只接受非空、含内联节点的 Clash YAML；base64 或仅含 `proxy-providers` 的响应会在写入前拒绝，因为 Verge 不能按本模板原位刷新它们。

## 固定模板

| 层 | 行为 |
|---|---|
| Verge | `verge-mihomo`、mixed `7897`、TUN/系统代理/开机启动/代理守护开启，SOCKS/HTTP 独立端口关闭 |
| Mihomo | `config.yaml` 与脚本共同固定 `mode: rule`、`stack: mips`、IPv6、`find-process-mode: always`、`strict-route: false`，避免 GUI 覆盖 |
| DNS | fake-ip；国内 `223.5.5.5`/`119.29.29.29`，国外 DoH `1.1.1.1`/`8.8.8.8` |
| 节点组 | 从订阅内联节点重建“节点选择”和“自动选择”，不保留订阅原规则或旧节点名；IPv4/IPv6 服务器直连，保留名会明确报错 |
| 分流 | 节点服务器与私网直连 → 国内域名/GEOSITE/GEOIP 直连 → 非中国 GEOSITE 走节点 → `MATCH,节点选择` |

## Tailscale 条件层

安装器通过服务、程序和卸载注册表检测 Tailscale；仅检测到时启用：

- 三个 Tailscale 进程、UDP 源端口 41641、`100.64.0.0/10`、`100.100.100.100/32`、`fd7a:115c:a1e0::/48`、`ts.net`、`tailscale.io` 直连。
- `+.ts.net` 使用 `100.100.100.100`；Tailscale 域名排除 fake-ip，并执行 `tailscale set --accept-dns=true`。
- Verge 与 WinINet 持久绕过加入通配规则 `*.ts.net`，避免浏览器请求进入 Mihomo；单机专用地址不得写入通用模板。
- 保持 `tun['route-exclude-address']` 未设置；最长前缀路由由 Tailscale 自己管理。
- `tailscale.com` 不强制 DIRECT，仍走普通国内外分流。

未检测到 Tailscale 时，上述规则、DNS 过滤和 policy 全部省略。之后安装或卸载 Tailscale，需要重跑安装器以重渲染条件层；Tailscale 账户登录不属于脚本范围。

## 验证

```pwsh
node --test "<skill目录>\tests\profile.test.js"
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\tests\installer.test.ps1"
```

安装器测试使用临时目录和本机 HTTP 服务，不修改真实 Clash、系统代理或服务；测试需要 Node.js 和 Python，安装器本身不依赖它们。新机器最终还应确认应用成功启动、`7897` 可连接；若有 Tailscale，再检查 `tailscale status` 与一个 peer 的连通性。

## Common Mistakes

- 把远程订阅改成 Local 或 `proxy-providers`：会破坏 Verge 的原地更新方式；使用 remote profile + 每 profile script。
- 把 `mips` 改成 `mixed`，或用 DNS `fallback` 替换当前 `nameserver-policy`：不再是当前模板。
- 保留订阅原有 groups/rules：会引入旧节点名和不可控分流；必须重建。
- 为“共存”添加 `route-exclude-address` 或 `tailscale.com,DIRECT`：当前环境明确不使用这两条。
