---
name: configuring-clash-proxy
description: Use when assessing or configuring Windows Clash Verge Rev/Mihomo, choosing proxy ports/TUN/DNS/routing, migrating a replaceable subscription, or optionally integrating Tailscale.
---

# Configuring Clash Proxy

## Overview

这是帮助 agent 配置环境的通用模板，不是所有机器都必须套用的实现。`templates/settings.json` 中的值只是参考默认值；先检查目标机器和用户需求，再决定保留、修改或省略哪些行为。

## 配置流程

1. 检查 Windows、Clash Verge/Mihomo 是否已安装、现有代理端口与配置、订阅形式，以及 Tailscale 是否存在。
2. 与用户确认需要的变化。不要默认覆盖现有环境，不要把旧机器的端口、域名、IP、bypass 或节点选择当作目标机器需求。
3. 默认配置可直接使用；需要调整时，把 `templates/settings.json` 完整复制到仓库外的本地文件，修改后通过 `-SettingsPath` 传入。
4. 应用后验证实际端口、生成规则和连接命中。fake-ip 不能证明流量走了 DIRECT 还是代理。

在管理员 PowerShell 7 中运行：

```pwsh
# 使用参考默认值
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\scripts\Install-ClashProxy.ps1" -SubscriptionUrl "<订阅链接>"

# 使用机器自己的设置
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\scripts\Install-ClashProxy.ps1" -SubscriptionUrl "<订阅链接>" -SettingsPath "<本地 settings.json>"
```

## 可调整层

| settings 字段 | 控制内容 |
|---|---|
| `mixedPort`、`mode`、`allowLan`、`ipv6`、`language` | 基础 Mihomo/Verge 行为 |
| `tun` | 是否启用 TUN、stack、strict-route |
| `systemProxy` | 系统代理、开机启动、代理守护、机器自己的额外 bypass；关闭时不改写 WinINET |
| `updateIntervalMinutes` | 订阅更新分钟数；`0` 禁止自动更新 |
| `proxyGroups` | 选择组/测速组名称与测速参数 |
| `routing` | 节点服务器直连、是否使用参考国内分流、额外域名及前置/后置规则 |
| `dns` | fake-ip、DNS 服务器和额外过滤器 |
| `tailscale` | `enabled` 是总开关（默认关闭）；另可控制 accept-dns 和 `*.ts.net` bypass |

`routing.useDefaultSplitRules=false` 会省略参考国内分流，只保留自定义规则和最终 MATCH。机器专用域名、IP、主机名和 tailnet 信息只能放在该机器的 settings 或 Clash profile 中，不得写回本 skill。

## Tailscale

安装器仅检测已安装的 Tailscale，不安装或登录。只有 `tailscale.enabled=true` 且检测到时才应用进程/网段直连、MagicDNS 和 fake-ip 排除；`acceptDns`、`bypassTsNet` 可分别关闭。`acceptDns=false` 不修改现有 DNS 状态；启用后若安装失败会恢复原状态。未检测到或未启用时省略该层。不要设置 `tun.route-exclude-address` 作为默认共存方案。

## 安全与验证

安装器支持 YAML 内联节点订阅，备份受管文件，端口就绪后才修改系统代理，失败时恢复配置。base64、空订阅和仅 `proxy-providers` 的响应会在写入前拒绝。订阅 URL 不打印到日志。

```pwsh
node --test "<skill目录>\tests\profile.test.js"
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\tests\installer.test.ps1"
```

测试需要 Node.js 和 Python，安装器本身不依赖它们。

## Common Mistakes

- 把参考默认值当成必须实现的目标。
- 未检查目标环境就直接覆盖配置。
- 把公司域名、NAS 地址、账户信息或真实订阅提交到模板。
- 文档允许配置，但脚本仍读取硬编码值；新增 settings 字段时必须同步渲染与行为测试。
