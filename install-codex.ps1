param(
    [string]$CodexHome = "$env:USERPROFILE\.codex",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "AgentToastNotify"),
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$hooksPath = Join-Path $CodexHome "hooks.json"
$backupPath = "$hooksPath.bak-agent-toast"

Write-Host "Installing Agent Toast Notify for Codex"
Write-Host "CodexHome: $CodexHome"
Write-Host "InstallDir: $InstallDir"

if ($WhatIf) {
    Write-Host "WhatIf: would copy scripts to $InstallDir and merge hooks.json"
    exit 0
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Force -Path (Join-Path $PSScriptRoot "scripts\*.ps1") -Destination $InstallDir
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot "assets")) {
    Copy-Item -Recurse -Force -Path (Join-Path $PSScriptRoot "assets") -Destination $InstallDir
}

if (Test-Path -LiteralPath $hooksPath) {
    Copy-Item -Force $hooksPath $backupPath
    $hooks = Get-Content -LiteralPath $hooksPath -Raw | ConvertFrom-Json
} else {
    New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
    $hooks = [pscustomobject]@{ hooks = [pscustomobject]@{} }
}

if (-not $hooks.PSObject.Properties["hooks"]) {
    $hooks | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
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

$codexNotify = Join-Path $InstallDir "codex-notify.ps1"
$permissionCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$codexNotify`" permission-request"
$stopCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$codexNotify`" stop"

$permissionGroup = [pscustomobject]@{
    matcher = "*"
    hooks = @([pscustomobject]@{
        type = "command"
        command = $permissionCommand
        timeout = 5
        statusMessage = "Sending permission notification"
    })
}

$stopGroup = [pscustomobject]@{
    hooks = @([pscustomobject]@{
        type = "command"
        command = $stopCommand
        timeout = 5
        statusMessage = "Sending stop notification"
    })
}

Set-HookGroup -HooksContainer $hooks.hooks -EventName "PermissionRequest" -NewGroup $permissionGroup -CommandPattern "codex-notify\.ps1.*permission-request"
Set-HookGroup -HooksContainer $hooks.hooks -EventName "Stop" -NewGroup $stopGroup -CommandPattern "codex-notify\.ps1.*stop"

$hooks | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $hooksPath -Encoding UTF8

Write-Host "Installed. Open /hooks in Codex and trust the new hooks if prompted."
