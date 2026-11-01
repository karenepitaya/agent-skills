#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionUrl,
    [string]$ConfigRoot = (Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge-rev'),
    [string]$SettingsPath,
    [string]$InternetSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
    [switch]$SkipInstall,
    [switch]$SkipService,
    [switch]$SkipStart,
    [switch]$SkipSystemProxy,
    [switch]$SkipTailscaleSetup,
    [ValidateRange(0, 300)]
    [int]$StartupTimeoutSeconds = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$templateRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'templates'

function Write-TextFile {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Find-ClashVerge {
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $entries = Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -eq 'Clash Verge' -and
            $_.PSObject.Properties['InstallLocation'] -and $_.InstallLocation
        }
    foreach ($entry in $entries) {
        $candidate = Join-Path ($entry.InstallLocation.Trim('"')) 'clash-verge.exe'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    $command = Get-Command 'clash-verge.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Clash Verge\clash-verge.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Clash Verge\clash-verge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Clash Verge\clash-verge.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

function Test-TailscaleInstalled {
    if (Get-Service -Name Tailscale -ErrorAction SilentlyContinue) { return $true }
    if (Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe')) { return $true }
    if (Get-Command 'tailscale.exe' -ErrorAction SilentlyContinue) { return $true }
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    return [bool](Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -eq 'Tailscale' } |
        Select-Object -First 1)
}

function Find-TailscaleExecutable {
    $executable = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (Test-Path -LiteralPath $executable) { return $executable }
    $command = Get-Command 'tailscale.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'Tailscale was detected but tailscale.exe could not be located.'
}

function Set-TailscaleDns {
    param([bool]$Enabled)
    $executable = Find-TailscaleExecutable
    $preferences = & $executable debug prefs
    if ($LASTEXITCODE -ne 0) { throw "Failed to read Tailscale DNS state (exit $LASTEXITCODE)." }
    $previous = [bool]($preferences | ConvertFrom-Json).CorpDNS
    $acceptDns = $Enabled.ToString().ToLowerInvariant()
    & $executable set "--accept-dns=$acceptDns" | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Failed to set Tailscale DNS (exit $LASTEXITCODE)." }
    return $previous
}

function Get-SubscriptionText {
    param([string]$Url)
    $uri = [Uri]$Url
    if ($uri.Scheme -ne 'https' -and $uri.Scheme -ne 'http') {
        throw 'SubscriptionUrl must use HTTP or HTTPS.'
    }

    $tempFile = [IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $tempFile -UseBasicParsing -UserAgent 'clash-verge/v2.5.8' -TimeoutSec 60 -NoProxy
        $text = [IO.File]::ReadAllText($tempFile, [Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
        $proxyBlock = [regex]::Match($text, '(?ms)^proxies[ \t]*:[ \t]*(?<value>.*?)(?=^[A-Za-z_][A-Za-z0-9_-]*[ \t]*:|\z)')
        $hasBlockNodes = $proxyBlock.Success -and [regex]::IsMatch($proxyBlock.Groups['value'].Value, '(?m)^\s+-\s+')
        $hasFlowNodes = $proxyBlock.Success -and [regex]::IsMatch($proxyBlock.Groups['value'].Value, '^\s*\[\s*\{')
        if ($hasBlockNodes -or $hasFlowNodes) { return $text }
        throw 'Subscription must be nonempty Clash YAML with inline proxies; base64 and provider-only responses are not supported.'
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Backup-ManagedFile {
    param([string]$Path, [string]$BackupRoot, [string]$RelativePath)
    if (Test-Path -LiteralPath $Path) {
        $destination = Join-Path $BackupRoot $RelativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $Path -Destination $destination -Force
    }
}

function Restore-ManagedFile {
    param([string]$Path, [string]$BackupRoot, [string]$RelativePath)
    $backup = Join-Path $BackupRoot $RelativePath
    if (Test-Path -LiteralPath $backup) {
        Copy-Item -LiteralPath $backup -Destination $Path -Force
    } elseif (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
}

function Get-PreservedProfileState {
    param([string]$Path, [string]$SubscriptionUrl)
    $state = @{ Items = ''; Selected = '' }
    if (-not (Test-Path -LiteralPath $Path)) { return $state }
    $existing = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    $items = [regex]::Matches($existing, '(?ms)^- uid:.*?(?=^- uid:|\z)')
    $preserved = @()
    foreach ($item in $items) {
        if ([regex]::IsMatch($item.Value, '(?m)^- uid: portable-(?:main|merge|script)\s*$')) {
            if ($item.Value -match '(?m)^- uid: portable-main\s*$') {
                $oldUrl = [regex]::Match($item.Value, "(?m)^  url: '(?<url>(?:''|[^'])*)'\s*$")
                if ($oldUrl.Success -and $oldUrl.Groups['url'].Value.Replace("''", "'") -eq $SubscriptionUrl) {
                    $selected = [regex]::Match($item.Value, '(?ms)^  selected:\r?\n(?:^(?:  -|    ).*\r?\n?)+')
                    if ($selected.Success) { $state.Selected = $selected.Value.TrimEnd() + "`n" }
                }
            }
        } else {
            $preserved += $item.Value.TrimEnd()
        }
    }
    if ($preserved.Count) { $state.Items = ($preserved -join "`n") + "`n" }
    return $state
}

function Wait-ProxyPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutSeconds)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $client = New-Object Net.Sockets.TcpClient
        try {
            $pending = $client.ConnectAsync($HostName, $Port)
            if ($pending.Wait(1000) -and $client.Connected) { return $true }
        } catch {
            # Retry until the startup deadline.
        } finally {
            $client.Close()
        }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

if ($env:OS -ne 'Windows_NT') { throw 'This installer supports Windows only.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and (-not $SkipInstall -or -not $SkipService)) {
    throw 'Run this installer from an elevated Administrator PowerShell.'
}

if (-not $SettingsPath) { $SettingsPath = Join-Path $templateRoot 'settings.json' }
$settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
if ($settings.mixedPort -lt 1 -or $settings.mixedPort -gt 65535) { throw 'mixedPort must be between 1 and 65535.' }
if ($settings.mode -notin @('rule', 'global', 'direct')) { throw 'mode must be rule, global, or direct.' }
if ($settings.updateIntervalMinutes -lt 0) { throw 'updateIntervalMinutes must be zero or greater.' }
if (-not $settings.proxyGroups.selectName -or -not $settings.proxyGroups.autoName -or
    $settings.proxyGroups.selectName -eq $settings.proxyGroups.autoName -or
    $settings.proxyGroups.selectName -eq 'DIRECT' -or $settings.proxyGroups.autoName -eq 'DIRECT') {
    throw 'Proxy group names must be nonempty, distinct, and not DIRECT.'
}
$settingsJson = $settings | ConvertTo-Json -Depth 20 -Compress

$subscriptionText = Get-SubscriptionText -Url $SubscriptionUrl
$tailscaleDetected = Test-TailscaleInstalled
$previousTailscaleDns = $null
if ($tailscaleDetected -and $settings.tailscale.enabled -and $settings.tailscale.acceptDns -and -not $SkipTailscaleSetup) {
    $previousTailscaleDns = Set-TailscaleDns -Enabled $true
}
$clashExe = Find-ClashVerge
if (-not $clashExe -and -not $SkipInstall) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) { throw 'Clash Verge is missing and winget is unavailable.' }
    & $winget.Source install --id ClashVergeRev.ClashVergeRev --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "winget failed to install Clash Verge (exit $LASTEXITCODE)." }
    $clashExe = Find-ClashVerge
}
if (-not $clashExe -and (-not $SkipService -or -not $SkipStart)) {
    throw 'Unable to locate clash-verge.exe.'
}

if (-not $SkipService -and -not (Get-Service -Name clash_verge_service -ErrorAction SilentlyContinue)) {
    $serviceInstaller = Join-Path (Split-Path -Parent $clashExe) 'resources\clash-verge-service-install.exe'
    if (-not (Test-Path -LiteralPath $serviceInstaller)) { throw 'Clash Verge service installer is missing.' }
    & $serviceInstaller | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Clash Verge service installation failed (exit $LASTEXITCODE)." }
}

$backupRoot = Join-Path $ConfigRoot ('portable-proxy-backups\' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
$managedRelativePaths = @(
    'verge.yaml',
    'config.yaml',
    'profiles.yaml',
    'profiles\portable-main.yaml',
    'profiles\portable-script.js',
    'profiles\portable-merge.yaml'
)
foreach ($relative in $managedRelativePaths) {
    Backup-ManagedFile -Path (Join-Path $ConfigRoot $relative) -BackupRoot $backupRoot -RelativePath $relative
}
$profileState = Get-PreservedProfileState -Path (Join-Path $ConfigRoot 'profiles.yaml') -SubscriptionUrl $SubscriptionUrl
$previousInternetSettings = $null

try {
    if (-not $SkipStart) {
        Get-Process -Name 'clash-verge' -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name 'verge-mihomo', 'verge-mihomo-alpha' -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1
    }

    $profileTemplate = [IO.File]::ReadAllText((Join-Path $templateRoot 'profile.js'), [Text.Encoding]::UTF8)
    $tailscaleLiteral = if ($tailscaleDetected) { 'true' } else { 'false' }
    $renderedProfile = $profileTemplate.Replace('__TAILSCALE_ENABLED__', $tailscaleLiteral).Replace('__SETTINGS__', $settingsJson)
    $bypassEntries = @($settings.systemProxy.additionalBypass)
    if ($tailscaleDetected -and $settings.tailscale.enabled -and $settings.tailscale.bypassTsNet) { $bypassEntries += '*.ts.net' }
    $systemProxyBypass = if ($bypassEntries.Count) { '"' + ($bypassEntries -join ';') + '"' } else { 'null' }
    $tunEnabled = $settings.tun.enabled.ToString().ToLowerInvariant()
    $systemProxyEnabled = $settings.systemProxy.enabled.ToString().ToLowerInvariant()
    $autoLaunch = $settings.systemProxy.autoLaunch.ToString().ToLowerInvariant()
    $proxyGuard = $settings.systemProxy.proxyGuard.ToString().ToLowerInvariant()
    $vergeTemplate = [IO.File]::ReadAllText((Join-Path $templateRoot 'verge.yaml'), [Text.Encoding]::UTF8)
    $vergeTemplate = $vergeTemplate.Replace('__LANGUAGE__', [string]$settings.language).Replace('__TUN_ENABLED__', $tunEnabled).Replace('__AUTO_LAUNCH__', $autoLaunch).Replace('__SYSTEM_PROXY_ENABLED__', $systemProxyEnabled).Replace('__PROXY_GUARD__', $proxyGuard).Replace('__MIXED_PORT__', [string]$settings.mixedPort).Replace('__SYSTEM_PROXY_BYPASS__', $systemProxyBypass)
    $coreTemplate = [IO.File]::ReadAllText((Join-Path $templateRoot 'config.yaml'), [Text.Encoding]::UTF8)
    $coreTemplate = $coreTemplate.Replace('__MIXED_PORT__', [string]$settings.mixedPort).Replace('__LOG_LEVEL__', [string]$settings.logLevel).Replace('__ALLOW_LAN__', $settings.allowLan.ToString().ToLowerInvariant()).Replace('__IPV6__', $settings.ipv6.ToString().ToLowerInvariant()).Replace('__MODE__', [string]$settings.mode).Replace('__TUN_ENABLED__', $tunEnabled).Replace('__TUN_STACK__', [string]$settings.tun.stack).Replace('__STRICT_ROUTE__', $settings.tun.strictRoute.ToString().ToLowerInvariant())
    $mergeTemplate = [IO.File]::ReadAllText((Join-Path $templateRoot 'merge.yaml'), [Text.Encoding]::UTF8)
    $escapedUrl = $SubscriptionUrl.Replace("'", "''")
    $updated = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $autoUpdate = ($settings.updateIntervalMinutes -gt 0).ToString().ToLowerInvariant()
    $updateInterval = $settings.updateIntervalMinutes
    $preservedItems = $profileState.Items
    $selectedBlock = $profileState.Selected
    $profilesIndex = @"
# Profiles Config for Clash Verge

current: portable-main
items:
${preservedItems}- uid: portable-merge
  type: merge
  name: Portable merge
  file: portable-merge.yaml
  updated: $updated
- uid: portable-script
  type: script
  name: Portable routing
  file: portable-script.js
  updated: $updated
- uid: portable-main
  type: remote
  name: Portable subscription
  file: portable-main.yaml
  url: '$escapedUrl'
$selectedBlock  updated: $updated
  option:
    allow_auto_update: $autoUpdate
    update_interval: $updateInterval
    merge: portable-merge
    script: portable-script
"@

    Write-TextFile -Path (Join-Path $ConfigRoot 'verge.yaml') -Content $vergeTemplate
    Write-TextFile -Path (Join-Path $ConfigRoot 'config.yaml') -Content $coreTemplate
    Write-TextFile -Path (Join-Path $ConfigRoot 'profiles.yaml') -Content $profilesIndex
    Write-TextFile -Path (Join-Path $ConfigRoot 'profiles\portable-main.yaml') -Content $subscriptionText
    Write-TextFile -Path (Join-Path $ConfigRoot 'profiles\portable-script.js') -Content $renderedProfile
    Write-TextFile -Path (Join-Path $ConfigRoot 'profiles\portable-merge.yaml') -Content $mergeTemplate

    if (-not $SkipStart) {
        Start-Process -FilePath $clashExe
        if (-not (Wait-ProxyPort -HostName '127.0.0.1' -Port $settings.mixedPort -TimeoutSeconds $StartupTimeoutSeconds)) {
            throw "Clash Verge started but 127.0.0.1:$($settings.mixedPort) is not listening. Check $ConfigRoot\logs."
        }
    }

    if (-not $SkipSystemProxy -and $settings.systemProxy.enabled) {
        $internetSettings = $InternetSettingsPath
        $previousInternetSettings = Get-ItemProperty -Path $internetSettings
        $proxyEnableValue = if ($settings.systemProxy.enabled) { 1 } else { 0 }
        Set-ItemProperty -Path $internetSettings -Name ProxyEnable -Type DWord -Value $proxyEnableValue
        Set-ItemProperty -Path $internetSettings -Name ProxyServer -Value "127.0.0.1:$($settings.mixedPort)"
        $proxyOverride = ';localhost.*;;localhost;127.*;192.168.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;<local>'
        foreach ($entry in $bypassEntries) { $proxyOverride += ';' + $entry }
        Set-ItemProperty -Path $internetSettings -Name ProxyOverride -Value $proxyOverride
        Remove-ItemProperty -Path $internetSettings -Name AutoConfigURL -ErrorAction SilentlyContinue
        if (-not ('PortableProxy.WinInet' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace PortableProxy {
    public static class WinInet {
        [DllImport("wininet.dll", SetLastError = true)]
        public static extern bool InternetSetOption(IntPtr hInternet, int option, IntPtr buffer, int length);
    }
}
'@
        }
        [void][PortableProxy.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
        [void][PortableProxy.WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
    }
} catch {
    if (-not $SkipStart) {
        Get-Process -Name 'clash-verge', 'verge-mihomo', 'verge-mihomo-alpha' -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    if ($null -ne $previousTailscaleDns -and -not $previousTailscaleDns) {
        Set-TailscaleDns -Enabled $false | Out-Null
    }
    if ($previousInternetSettings) {
        Set-ItemProperty -Path $InternetSettingsPath -Name ProxyEnable -Value $previousInternetSettings.ProxyEnable
        Set-ItemProperty -Path $InternetSettingsPath -Name ProxyServer -Value $previousInternetSettings.ProxyServer
        Set-ItemProperty -Path $InternetSettingsPath -Name ProxyOverride -Value $previousInternetSettings.ProxyOverride
        if ($previousInternetSettings.PSObject.Properties['AutoConfigURL']) {
            Set-ItemProperty -Path $InternetSettingsPath -Name AutoConfigURL -Value $previousInternetSettings.AutoConfigURL
        } else {
            Remove-ItemProperty -Path $InternetSettingsPath -Name AutoConfigURL -ErrorAction SilentlyContinue
        }
        [void][PortableProxy.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
        [void][PortableProxy.WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
    }
    foreach ($relative in $managedRelativePaths) {
        Restore-ManagedFile -Path (Join-Path $ConfigRoot $relative) -BackupRoot $backupRoot -RelativePath $relative
    }
    throw
}

Write-Host "Portable Clash configuration written to $ConfigRoot"
Write-Host "Tailscale detected: $tailscaleDetected; layer enabled: $($tailscaleDetected -and $settings.tailscale.enabled)"
if (Test-Path -LiteralPath $backupRoot) { Write-Host "Previous managed files backed up to $backupRoot" }
