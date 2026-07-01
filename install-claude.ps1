param(
    [string]$ClaudeHome = "$env:USERPROFILE\.claude",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "AgentToastNotify"),
    [string]$RepositoryRawBase = "https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$settingsPath = Join-Path $ClaudeHome "settings.json"
$backupPath = "$settingsPath.bak-agent-toast"

Write-Host "Installing Agent Toast Notify for Claude Code"
Write-Host "ClaudeHome: $ClaudeHome"
Write-Host "InstallDir: $InstallDir"

if ($WhatIf) {
    Write-Host "WhatIf: would install scripts to $InstallDir and merge settings.json"
    exit 0
}

function Install-AgentToastFiles {
    param(
        [string]$InstallDir,
        [string]$RepositoryRawBase
    )

    $scriptRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }
    $localScriptsDir = Join-Path $scriptRoot "scripts"
    $localAssetsDir = Join-Path $scriptRoot "assets"
    $assetsDir = Join-Path $InstallDir "assets"

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null

    if (Test-Path -LiteralPath (Join-Path $localScriptsDir "notify.ps1")) {
        Copy-Item -Force -Path (Join-Path $localScriptsDir "*.ps1") -Destination $InstallDir
        Copy-Item -Force -Path (Join-Path $localAssetsDir "agent-toast.png") -Destination $assetsDir
        return
    }

    $files = @(
        @{ Url = "$RepositoryRawBase/scripts/notify.ps1"; Path = (Join-Path $InstallDir "notify.ps1") },
        @{ Url = "$RepositoryRawBase/scripts/clifocus.ps1"; Path = (Join-Path $InstallDir "clifocus.ps1") },
        @{ Url = "$RepositoryRawBase/scripts/codex-notify.ps1"; Path = (Join-Path $InstallDir "codex-notify.ps1") },
        @{ Url = "$RepositoryRawBase/scripts/claude-notify.ps1"; Path = (Join-Path $InstallDir "claude-notify.ps1") },
        @{ Url = "$RepositoryRawBase/assets/agent-toast.png"; Path = (Join-Path $assetsDir "agent-toast.png") }
    )

    foreach ($file in $files) {
        Invoke-WebRequest -Uri $file.Url -OutFile $file.Path -UseBasicParsing
    }
}

Install-AgentToastFiles -InstallDir $InstallDir -RepositoryRawBase $RepositoryRawBase

function Register-CliFocusProtocol {
    param([string]$InstallDir)

    $clifocusScript = Join-Path $InstallDir "clifocus.ps1"
    $protocolKey = "HKCU:\Software\Classes\clifocus"
    $commandKey = Join-Path $protocolKey "shell\open\command"
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$clifocusScript`" `"%1`""

    $protocolRegistryKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\clifocus")
    $commandRegistryKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\clifocus\shell\open\command")
    try {
        $protocolRegistryKey.SetValue("", "URL:Agent Toast focus protocol")
        $protocolRegistryKey.SetValue("URL Protocol", "")
        $commandRegistryKey.SetValue("", $command)
    } finally {
        $commandRegistryKey.Dispose()
        $protocolRegistryKey.Dispose()
    }
}

Register-CliFocusProtocol -InstallDir $InstallDir

if (Test-Path -LiteralPath $settingsPath) {
    Copy-Item -Force $settingsPath $backupPath
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    New-Item -ItemType Directory -Force -Path $ClaudeHome | Out-Null
    $settings = [pscustomobject]@{}
}

if (-not $settings.PSObject.Properties["hooks"]) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}

function Set-HookGroup {
    param(
        [pscustomobject]$HooksContainer,
        [string]$EventName,
        [pscustomobject]$NewGroup,
        [string]$CommandPattern
    )

    $existingGroups = @()
    if ($HooksContainer.PSObject.Properties[$EventName]) {
        $existingGroups = @($HooksContainer.$EventName)
    }

    $keptGroups = @($existingGroups | Where-Object {
        $group = $_
        $commands = @($group.hooks | ForEach-Object { $_.command })
        -not ($commands | Where-Object { $_ -match $CommandPattern })
    })

    $HooksContainer | Add-Member -Force -NotePropertyName $EventName -NotePropertyValue @($keptGroups + $NewGroup)
}

$claudeNotify = Join-Path $InstallDir "claude-notify.ps1"

$permissionGroup = [pscustomobject]@{
    matcher = "permission_prompt"
    hooks = @([pscustomobject]@{
        type = "command"
        command = "& '$claudeNotify' permission-request"
        shell = "powershell"
    })
}

$stopGroup = [pscustomobject]@{
    hooks = @([pscustomobject]@{
        type = "command"
        command = "& '$claudeNotify' stop"
        shell = "powershell"
    })
}

Set-HookGroup -HooksContainer $settings.hooks -EventName "Notification" -NewGroup $permissionGroup -CommandPattern "claude-notify\.ps1.*permission-request"
Set-HookGroup -HooksContainer $settings.hooks -EventName "Stop" -NewGroup $stopGroup -CommandPattern "claude-notify\.ps1.*stop"

$json = $settings | ConvertTo-Json -Depth 20
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($settingsPath, $json, $utf8NoBom)

Write-Host "Installed. Restart Claude Code if hooks do not reload immediately."
