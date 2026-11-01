# configuring-clash-proxy

在新 Windows 电脑上复现 Clash Verge Rev + Mihomo 代理环境：规则模式、TUN、系统代理、fake-ip、国内直连/国外代理，并按检测结果处理 Tailscale 共存。

## 环境要求

- Windows 10/11，PowerShell 7+（`pwsh`）。
- 管理员 PowerShell。
- 一个非空、包含内联 `proxies` 的 Clash YAML 订阅链接。
- 缺少 Clash Verge Rev 时需要 `winget`；Tailscale 是可选项，脚本不会安装它或登录账户。
- 仅测试需要 Node.js 和 Python；运行安装器不需要它们。

## 安装

把整个 `configuring-clash-proxy` 目录复制到 agent 的 skills 目录，目录名保持不变。例如：

- omp：`~/.omp/agent/skills/`
- Claude：`~/.claude/skills/`
- 跨运行时：`~/.agents/skills/`

## 快速开始

在管理员 PowerShell 7 中运行：

```pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\scripts\Install-ClashProxy.ps1" -SubscriptionUrl "<订阅链接>"
```

脚本会安装缺失的 Clash Verge Rev/服务，备份受管配置，生成每小时更新的远程 profile，启动应用并检查 `127.0.0.1:7897`。端口就绪后才设置系统代理；写入或启动失败会恢复受管文件。

固定配置包括 mixed port `7897`、TUN `mips`、规则模式、fake-ip、国内直连/国外代理。订阅原节点组和规则不会保留，脚本会根据新订阅重建“节点选择”和“自动选择”。

检测到 Tailscale 时，还会：

- 启用 Tailscale DNS：`tailscale set --accept-dns=true`。
- 添加进程、WireGuard UDP、Tailscale 网段和 MagicDNS 直连规则。
- 将通配规则 `*.ts.net` 加入 Verge 与 WinINet 持久代理绕过；单机专用地址不进入通用模板。

未检测到 Tailscale 时不写入这些规则。之后安装或卸载 Tailscale，需要重跑安装器。

## 验证

```pwsh
node --test "<skill目录>\tests\profile.test.js"
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\tests\installer.test.ps1"
```

测试使用临时目录和本机 HTTP 服务，不修改真实 Clash、系统代理、服务或 Tailscale。

## 常见问题

### 订阅被拒绝

只支持可直接由 Clash Verge 原位刷新的非空 YAML 内联节点订阅。base64、仅含 `proxy-providers`、`proxies: []` 或空节点列表不受支持；先在订阅服务商处转换为 Clash YAML。

### Tailscale 域名或 NAS 页面返回 502

重跑安装器，确保 Tailscale 条件层已启用。它同时处理 Mihomo DIRECT、Windows 浏览器 bypass 和 Tailscale DNS；只添加其中一层不够。

### 如何恢复旧配置

成功运行前的受管文件保存在 Clash 配置目录的 `portable-proxy-backups\<时间戳>`。写入或启动失败时脚本会自动恢复，不需要手动回滚。

### 订阅链接会出现在哪里

链接必须写入 Clash Verge 的 `profiles.yaml` 才能自动更新，但不会打印到安装日志。不要把真实订阅链接提交到仓库。

### 是否支持 Tailscale 账户迁移

不支持。脚本只配置已安装 Tailscale 的网络共存；登录、授权和 tailnet 成员关系仍需单独完成。
