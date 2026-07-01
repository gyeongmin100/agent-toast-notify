param(
    [string]$CodexHome = "$env:USERPROFILE\.codex",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "AgentToastNotify"),
    [string]$RepositoryRawBase = "https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$hooksPath = Join-Path $CodexHome "hooks.json"
$backupPath = "$hooksPath.bak-agent-toast"

Write-Host "Installing Agent Toast Notify for Codex"
Write-Host "CodexHome: $CodexHome"
Write-Host "InstallDir: $InstallDir"

if ($WhatIf) {
    Write-Host "WhatIf: would install scripts to $InstallDir and merge hooks.json"
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
        Copy-Item -Force -Path (Join-Path $localScriptsDir "run-hidden.vbs") -Destination $InstallDir
        Copy-Item -Force -Path (Join-Path $localAssetsDir "agent-toast-48.png") -Destination $assetsDir
        return
    }

    $files = @(
        @{ Url = "$RepositoryRawBase/scripts/notify.ps1"; Path = (Join-Path $InstallDir "notify.ps1") },
        @{ Url = "$RepositoryRawBase/scripts/clifocus.ps1"; Path = (Join-Path $InstallDir "clifocus.ps1") },
        @{ Url = "$RepositoryRawBase/scripts/codex-notify.ps1"; Path = (Join-Path $InstallDir "codex-notify.ps1") },
        @{ Url = "$RepositoryRawBase/scripts/claude-notify.ps1"; Path = (Join-Path $InstallDir "claude-notify.ps1") },
        @{ Url = "$RepositoryRawBase/scripts/run-hidden.vbs"; Path = (Join-Path $InstallDir "run-hidden.vbs") },
        @{ Url = "$RepositoryRawBase/assets/agent-toast-48.png"; Path = (Join-Path $assetsDir "agent-toast-48.png") }
    )

    foreach ($file in $files) {
        Invoke-WebRequest -Uri $file.Url -OutFile $file.Path -UseBasicParsing
    }
}

Install-AgentToastFiles -InstallDir $InstallDir -RepositoryRawBase $RepositoryRawBase

function Register-CliFocusProtocol {
    param([string]$InstallDir)

    $clifocusScript = Join-Path $InstallDir "clifocus.ps1"
    $hiddenRunner = Join-Path $InstallDir "run-hidden.vbs"
    $protocolKey = "HKCU:\Software\Classes\clifocus"
    $commandKey = Join-Path $protocolKey "shell\open\command"
    $command = "wscript.exe //B //Nologo `"$hiddenRunner`" -File `"$clifocusScript`" `"%1`""

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

if (Test-Path -LiteralPath $hooksPath) {
    Copy-Item -Force $hooksPath $backupPath
    $hooks = Get-Content -LiteralPath $hooksPath -Raw -Encoding UTF8 | ConvertFrom-Json
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

$json = $hooks | ConvertTo-Json -Depth 20
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($hooksPath, $json, $utf8NoBom)

Write-Host "Installed. Open /hooks in Codex and trust the new hooks if prompted."
