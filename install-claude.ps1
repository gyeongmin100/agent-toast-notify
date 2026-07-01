param(
    [string]$ClaudeHome = "$env:USERPROFILE\.claude",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "AgentToastNotify"),
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$settingsPath = Join-Path $ClaudeHome "settings.json"
$backupPath = "$settingsPath.bak-agent-toast"

Write-Host "Installing Agent Toast Notify for Claude Code"
Write-Host "ClaudeHome: $ClaudeHome"
Write-Host "InstallDir: $InstallDir"

if ($WhatIf) {
    Write-Host "WhatIf: would copy scripts to $InstallDir and merge settings.json"
    exit 0
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Force -Path (Join-Path $PSScriptRoot "scripts\*.ps1") -Destination $InstallDir
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot "assets")) {
    Copy-Item -Recurse -Force -Path (Join-Path $PSScriptRoot "assets") -Destination $InstallDir
}

if (Test-Path -LiteralPath $settingsPath) {
    Copy-Item -Force $settingsPath $backupPath
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
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

$settings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $settingsPath -Encoding UTF8

Write-Host "Installed. Restart Claude Code if hooks do not reload immediately."
