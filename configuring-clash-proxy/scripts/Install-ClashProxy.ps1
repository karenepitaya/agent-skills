#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionUrl,
    [string]$ConfigRoot = (Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge-rev'),
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

function Enable-TailscaleDns {
    $executable = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (-not (Test-Path -LiteralPath $executable)) {
        $command = Get-Command 'tailscale.exe' -ErrorAction SilentlyContinue
        if ($command) { $executable = $command.Source }
    }
    if (-not $executable -or -not (Test-Path -LiteralPath $executable)) {
        throw 'Tailscale was detected but tailscale.exe could not be located.'
    }
    & $executable set --accept-dns=true | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Failed to enable Tailscale DNS (exit $LASTEXITCODE)." }
}

function Get-SubscriptionText {
    param([string]$Url)
    $uri = [Uri]$Url
    if ($uri.Scheme -ne 'https' -and $uri.Scheme -ne 'http') {
        throw 'SubscriptionUrl must use HTTP or HTTPS.'
    }

    $tempFile = [IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $tempFile -UseBasicParsing -UserAgent 'clash-verge/v2.5.8' -TimeoutSec 60
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

$subscriptionText = Get-SubscriptionText -Url $SubscriptionUrl
$tailscaleDetected = Test-TailscaleInstalled
if ($tailscaleDetected -and -not $SkipTailscaleSetup) { Enable-TailscaleDns }
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

try {
    if (-not $SkipStart) {
        Get-Process -Name 'clash-verge' -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name 'verge-mihomo', 'verge-mihomo-alpha' -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1
    }

    $profileTemplate = [IO.File]::ReadAllText((Join-Path $templateRoot 'profile.js'), [Text.Encoding]::UTF8)
    $tailscaleLiteral = if ($tailscaleDetected) { 'true' } else { 'false' }
    $renderedProfile = $profileTemplate.Replace('__TAILSCALE_ENABLED__', $tailscaleLiteral)
    $vergeTemplate = [IO.File]::ReadAllText((Join-Path $templateRoot 'verge.yaml'), [Text.Encoding]::UTF8)
    $systemProxyBypass = 'null'
    if ($tailscaleDetected) { $systemProxyBypass = '"*.ts.net"' }
    $vergeTemplate = $vergeTemplate.Replace('__SYSTEM_PROXY_BYPASS__', $systemProxyBypass)
    $coreTemplate = [IO.File]::ReadAllText((Join-Path $templateRoot 'config.yaml'), [Text.Encoding]::UTF8)
    $mergeTemplate = [IO.File]::ReadAllText((Join-Path $templateRoot 'merge.yaml'), [Text.Encoding]::UTF8)
    $escapedUrl = $SubscriptionUrl.Replace("'", "''")
    $updated = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
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
    allow_auto_update: true
    update_interval: 3600
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
        if (-not (Wait-ProxyPort -HostName '127.0.0.1' -Port 7897 -TimeoutSeconds $StartupTimeoutSeconds)) {
            throw "Clash Verge started but 127.0.0.1:7897 is not listening. Check $ConfigRoot\logs."
        }
    }

    if (-not $SkipSystemProxy) {
        $internetSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        Set-ItemProperty -Path $internetSettings -Name ProxyEnable -Type DWord -Value 1
        Set-ItemProperty -Path $internetSettings -Name ProxyServer -Value '127.0.0.1:7897'
        $proxyOverride = ';localhost.*;;localhost;127.*;192.168.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;<local>'
        if ($tailscaleDetected) { $proxyOverride += ';*.ts.net' }
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
    foreach ($relative in $managedRelativePaths) {
        Restore-ManagedFile -Path (Join-Path $ConfigRoot $relative) -BackupRoot $backupRoot -RelativePath $relative
    }
    throw
}

Write-Host "Portable Clash configuration written to $ConfigRoot"
Write-Host "Tailscale layer: $tailscaleDetected"
if (Test-Path -LiteralPath $backupRoot) { Write-Host "Previous managed files backed up to $backupRoot" }
