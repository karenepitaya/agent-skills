# configuring-clash-proxy

用于帮助配置 Windows Clash Verge Rev + Mihomo 环境的通用模板。默认值是一套可运行参考，不是每台机器都必须达到的目标。

## 环境要求

- Windows 10/11，PowerShell 7+（`pwsh`）和管理员权限。
- 非空、包含内联 `proxies` 的 Clash YAML 订阅链接。
- 缺少 Clash Verge Rev 时需要 `winget`。
- Tailscale 可选；脚本不会安装它或登录账户。
- 仅测试需要 Node.js 和 Python。

## 安装

将整个 `configuring-clash-proxy` 目录复制到 agent 的 skills 目录，目录名保持不变。例如 `~/.omp/agent/skills/`、`~/.claude/skills/` 或 `~/.agents/skills/`。

## 快速开始

先检查目标机器现有配置。如果参考默认值合适，可直接运行：

```pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\scripts\Install-ClashProxy.ps1" -SubscriptionUrl "<订阅链接>"
```

需要调整时，完整复制 `templates/settings.json` 到仓库外，修改后运行：

```pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\scripts\Install-ClashProxy.ps1" -SubscriptionUrl "<订阅链接>" -SettingsPath "<本地 settings.json>"
```

脚本会安装缺失的 Clash Verge Rev/服务、备份受管文件、生成远程 profile、启动应用并检查所选端口。端口就绪后才应用系统代理设置；写入或启动失败会恢复受管文件。

## 设置说明

| 字段 | 用途 |
|---|---|
| `mixedPort`、`mode`、`allowLan`、`ipv6`、`language` | 基础代理和界面行为 |
| `tun` | TUN 开关、stack 和 strict-route |
| `systemProxy` | 系统代理、开机启动、代理守护及额外 bypass；关闭时不改写 WinINET/PAC |
| `updateIntervalMinutes` | 订阅更新分钟数；`0` 关闭自动更新 |
| `proxyGroups` | 节点选择/自动测速组名称及测速参数 |
| `routing.directProxyServers` | 是否让节点服务器地址直连 |
| `routing.useDefaultSplitRules` | 是否采用参考的国内直连/国外代理规则 |
| `routing.directDomains`、`proxyDomains` | 本机额外精确域名规则 |
| `routing.prependRules`、`appendRules` | 本机额外 Mihomo 规则 |
| `dns` | fake-ip、DNS 服务器与过滤器 |
| `tailscale` | `enabled` 是总开关（默认关闭）；另可控制 accept-dns 和 `*.ts.net` bypass |

设置文件必须是完整 JSON，不是补丁。机器专用域名、IP、主机名、tailnet 标识和真实订阅只能保存在本地设置或 Clash profile 中，不要提交到模板仓库。

## Tailscale

只有 `tailscale.enabled=true` 且检测到 Tailscale 时，才应用进程/网段直连、MagicDNS、fake-ip 排除及可选的 accept-dns、`*.ts.net` bypass。默认不启用；未安装时自动省略。`acceptDns=false` 不修改现有 DNS 状态，启用后若安装失败会恢复原状态。Tailscale 登录、授权和 tailnet 成员关系不属于脚本范围。

## 验证

```pwsh
node --test "<skill目录>\tests\profile.test.js"
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill目录>\tests\installer.test.ps1"
```

测试使用临时目录和本机 HTTP 服务，不修改真实 Clash、系统代理、服务或 Tailscale。实际配置后还应检查应用日志和连接命中，不能根据 fake-ip 判断是否直连。

## 常见问题

### 订阅被拒绝

支持可由 Clash Verge 原位刷新的非空 YAML 内联节点订阅。base64、仅含 `proxy-providers`、`proxies: []` 或空节点列表不受支持。

### 只想改一项配置

仍需复制完整 settings 文件，但只需修改目标字段。其他字段保持默认值即可；默认值不是强制要求。

### 如何恢复旧配置

成功运行前的受管文件位于 Clash 配置目录的 `portable-proxy-backups\<时间戳>`。写入或启动失败时脚本自动恢复。

### 订阅链接会出现在哪里

链接写入 Clash Verge 的 `profiles.yaml` 以支持更新，但不会打印到安装日志，也不应提交到公开仓库。
