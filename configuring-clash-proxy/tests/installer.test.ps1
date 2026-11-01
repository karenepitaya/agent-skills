#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$skillRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $skillRoot 'scripts\Install-ClashProxy.ps1'
if (-not (Test-Path -LiteralPath $installer)) { throw 'Install-ClashProxy.ps1 must exist' }

function Assert-TextContains {
    param([string]$Path, [string]$Expected, [string]$Message)
    $content = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    if (-not $content.Contains($Expected)) { throw $Message }
}

$testRoot = Join-Path $env:TEMP ('clash proxy skill test ' + [Guid]::NewGuid().ToString('N'))
$webRoot = Join-Path $testRoot 'web content'
$configRoot = Join-Path $testRoot 'config data'
New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
$subscription = @'
mixed-port: 7890
proxies:
  - name: Test Node
    type: ss
    server: 198.51.100.10
    port: 443
    cipher: aes-128-gcm
    password: test-only
rules:
  - MATCH,DIRECT
'@
[IO.File]::WriteAllText((Join-Path $webRoot 'subscription.yaml'), $subscription, (New-Object Text.UTF8Encoding($false)))

$portListener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$portListener.Start()
$port = ([Net.IPEndPoint]$portListener.LocalEndpoint).Port
$portListener.Stop()
$server = $null

try {
    $pythonArgs = @('-m', 'http.server', $port, '--bind', '127.0.0.1', '--directory', ('"{0}"' -f $webRoot))
    $server = Start-Process -FilePath python -ArgumentList $pythonArgs -PassThru -WindowStyle Hidden
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $client = [Net.Sockets.TcpClient]::new()
            $client.Connect('127.0.0.1', $port)
            $client.Dispose()
            $ready = $true
            break
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not $ready) { throw 'local subscription server did not start' }

    $url = "http://127.0.0.1:$port/subscription.yaml"
    & $installer -SubscriptionUrl $url -ConfigRoot $configRoot -SkipInstall -SkipService -SkipStart -SkipSystemProxy -SkipTailscaleSetup

    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $tailscaleRegistered = Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -eq 'Tailscale' } |
        Select-Object -First 1
    $tailscaleDetected = [bool](Get-Service -Name Tailscale -ErrorAction SilentlyContinue) -or
        (Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe')) -or
        [bool](Get-Command 'tailscale.exe' -ErrorAction SilentlyContinue) -or [bool]$tailscaleRegistered
    $generated = Join-Path $configRoot 'profiles\portable-script.js'
    & node (Join-Path $PSScriptRoot 'assert-generated.js') $generated ($tailscaleDetected.ToString().ToLowerInvariant())
    if ($LASTEXITCODE -ne 0) { throw 'generated profile behavior assertion failed' }

    $profilesPath = Join-Path $configRoot 'profiles.yaml'
    $coreConfigPath = Join-Path $configRoot 'config.yaml'
    Assert-TextContains -Path $profilesPath -Expected 'update_interval: 3600' -Message 'remote profile must update hourly'
    Assert-TextContains -Path $coreConfigPath -Expected 'stack: mips' -Message 'GUI-owned TUN stack must be mips'
    Assert-TextContains -Path $coreConfigPath -Expected 'strict-route: false' -Message 'GUI-owned strict-route must be false'
    if ([IO.File]::ReadAllText($coreConfigPath).Contains('route-exclude-address')) {
        throw 'GUI-owned config must not retain route-exclude-address'
    }
    $vergeConfigPath = Join-Path $configRoot 'verge.yaml'
    if ($tailscaleDetected) {
        Assert-TextContains -Path $vergeConfigPath -Expected 'system_proxy_bypass: "*.ts.net"' -Message 'Tailscale layer must persist only the generic browser bypass'
    } else {
        Assert-TextContains -Path $vergeConfigPath -Expected 'system_proxy_bypass: null' -Message 'base layer must keep the default proxy bypass'
    }

    $statefulIndex = [IO.File]::ReadAllText($profilesPath, [Text.Encoding]::UTF8)
    $selected = "  selected:`n  - name: 节点选择`n    now: Test Node`n"
    $statefulIndex = $statefulIndex.Replace('  option:', ($selected + '  option:'))
    $statefulIndex += "`n- uid: other-profile`n  type: local`n  name: Keep me`n  file: other.yaml`n"
    [IO.File]::WriteAllText($profilesPath, $statefulIndex, (New-Object Text.UTF8Encoding($false)))
    & $installer -SubscriptionUrl $url -ConfigRoot $configRoot -SkipInstall -SkipService -SkipStart -SkipSystemProxy -SkipTailscaleSetup
    Assert-TextContains -Path $profilesPath -Expected 'now: Test Node' -Message 'same-subscription rerun must preserve selection'
    Assert-TextContains -Path $profilesPath -Expected 'uid: other-profile' -Message 'rerun must preserve unrelated profiles'

    $beforeFailedUpdate = [IO.File]::ReadAllBytes($profilesPath)
    $invalidSubscriptions = @(
        'not a clash subscription',
        "proxies: []`nrules: [MATCH,DIRECT]",
        [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($subscription))
    )
    foreach ($invalid in $invalidSubscriptions) {
        [IO.File]::WriteAllText((Join-Path $webRoot 'subscription.yaml'), $invalid, (New-Object Text.UTF8Encoding($false)))
        $failed = $false
        try {
            & $installer -SubscriptionUrl $url -ConfigRoot $configRoot -SkipInstall -SkipService -SkipStart -SkipSystemProxy -SkipTailscaleSetup
        } catch {
            $failed = $true
        }
        if (-not $failed) { throw 'invalid or non-refreshable subscription must fail validation' }
        $afterFailedUpdate = [IO.File]::ReadAllBytes($profilesPath)
        if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$beforeFailedUpdate, [byte[]]$afterFailedUpdate)) {
            throw 'invalid subscription must not modify the active profile index'
        }
    }

    [IO.File]::WriteAllText((Join-Path $webRoot 'subscription.yaml'), $subscription, (New-Object Text.UTF8Encoding($false)))
    $managedFiles = @('verge.yaml', 'config.yaml', 'profiles.yaml', 'profiles\portable-main.yaml', 'profiles\portable-script.js', 'profiles\portable-merge.yaml')
    $beforeRollback = @{}
    foreach ($relative in $managedFiles) {
        $beforeRollback[$relative] = [IO.File]::ReadAllBytes((Join-Path $configRoot $relative))
    }

    function Get-Process { param($Name, $ErrorAction) return $null }
    function Stop-Process { param($Name, $Id, [switch]$Force, $ErrorAction) }
    function Start-Process { param($FilePath) }
    $startupFailed = $false
    try {
        & $installer -SubscriptionUrl $url -ConfigRoot $configRoot -SkipInstall -SkipService -SkipSystemProxy -SkipTailscaleSetup -StartupTimeoutSeconds 0
    } catch {
        $startupFailed = $true
        if ($_.Exception.Message -notmatch '7897') { throw }
    }
    if (-not $startupFailed) { throw 'zero-timeout startup probe must fail' }
    Remove-Item Function:\Get-Process, Function:\Stop-Process, Function:\Start-Process -ErrorAction SilentlyContinue

    foreach ($relative in $managedFiles) {
        $afterRollback = [IO.File]::ReadAllBytes((Join-Path $configRoot $relative))
        if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$beforeRollback[$relative], [byte[]]$afterRollback)) {
            throw "startup failure must restore $relative"
        }
    }

    Write-Host 'Installer integration tests passed'
} finally {
    Remove-Item Function:\Get-Process, Function:\Stop-Process, Function:\Start-Process -ErrorAction SilentlyContinue
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
