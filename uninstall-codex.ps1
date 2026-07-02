param(
    [string]$CodexHome = "$env:USERPROFILE\.codex",
    [string]$ClaudeHome = "$env:USERPROFILE\.claude",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "AgentToastNotify")
)

$ErrorActionPreference = "Stop"

$hooksPath = Join-Path $CodexHome "hooks.json"
$settingsPath = Join-Path $ClaudeHome "settings.json"
$backupPath = "$hooksPath.bak-agent-toast-uninstall"

Write-Host "Uninstalling Agent Toast Notify for Codex"
Write-Host "CodexHome: $CodexHome"
Write-Host "InstallDir: $InstallDir"

function Remove-AgentToastHookGroups {
    param(
        [pscustomobject]$HooksContainer,
        [string]$EventName,
        [string]$CommandPattern
    )

    if (-not $HooksContainer.PSObject.Properties[$EventName]) { return }

    $existingGroups = @($HooksContainer.$EventName)
    $keptGroups = @($existingGroups | Where-Object {
        $group = $_
        $commands = @($group.hooks | ForEach-Object { $_.command })
        -not ($commands | Where-Object { $_ -match $CommandPattern })
    })

    $HooksContainer.PSObject.Properties.Remove($EventName)
    if ($keptGroups.Count -gt 0) {
        $HooksContainer | Add-Member -NotePropertyName $EventName -NotePropertyValue $keptGroups
    }
}

function Test-AgentToastReference {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return $content -match "(codex-notify|claude-notify)\.ps1"
}

function Unregister-CliFocusProtocolIfUnused {
    param(
        [string]$HooksPath,
        [string]$SettingsPath
    )

    $codexStillUsesAgentToast = Test-AgentToastReference -Path $HooksPath
    $claudeStillUsesAgentToast = Test-AgentToastReference -Path $SettingsPath
    $protocolKey = "HKCU:\Software\Classes\clifocus"
    $commandKey = Join-Path $protocolKey "shell\open\command"

    if (-not $codexStillUsesAgentToast -and -not $claudeStillUsesAgentToast -and (Test-Path -LiteralPath $commandKey)) {
        $command = (Get-ItemProperty -LiteralPath $commandKey)."(default)"
        if ($command -match "AgentToastNotify\\clifocus\.ps1") {
            Remove-Item -LiteralPath $protocolKey -Recurse -Force
        }
    }
}

if (Test-Path -LiteralPath $hooksPath) {
    Copy-Item -Force $hooksPath $backupPath
    $hooks = Get-Content -LiteralPath $hooksPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($hooks.PSObject.Properties["hooks"]) {
        Remove-AgentToastHookGroups -HooksContainer $hooks.hooks -EventName "PermissionRequest" -CommandPattern "codex-notify\.ps1.*permission-request"
        Remove-AgentToastHookGroups -HooksContainer $hooks.hooks -EventName "Stop" -CommandPattern "codex-notify\.ps1.*stop"
        $json = $hooks | ConvertTo-Json -Depth 20
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($hooksPath, $json, $utf8NoBom)
    }
}

if (Test-Path -LiteralPath $InstallDir) {
    $codexStillUsesAgentToast = Test-AgentToastReference -Path $hooksPath
    $claudeStillUsesAgentToast = Test-AgentToastReference -Path $settingsPath

    if (-not $codexStillUsesAgentToast -and -not $claudeStillUsesAgentToast) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force
    } else {
        Write-Host "Kept shared files because another agent still references them."
    }
}

Unregister-CliFocusProtocolIfUnused -HooksPath $hooksPath -SettingsPath $settingsPath

function Remove-AgentToastAppRegistrations {
    param([string]$AppIdPrefix)

    $roots = @(
        "HKCU:\Software\Classes\AppUserModelId",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Backup"
    )
    foreach ($root in $roots) {
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -like "$AppIdPrefix*" } |
            ForEach-Object { Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Remove-AgentToastBackups {
    param([string]$BasePath)
    Remove-Item -Path "$BasePath.bak-agent-toast*" -Force -ErrorAction SilentlyContinue
}

function Remove-AgentToastSharedTempIfUnused {
    param(
        [string]$HooksPath,
        [string]$SettingsPath
    )

    $codexStillUsesAgentToast = Test-AgentToastReference -Path $HooksPath
    $claudeStillUsesAgentToast = Test-AgentToastReference -Path $SettingsPath

    if (-not $codexStillUsesAgentToast -and -not $claudeStillUsesAgentToast) {
        Remove-Item -LiteralPath (Join-Path $env:TEMP "agent-toast.log") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $env:TEMP "agent-toast-last-host-hwnd.txt") -Force -ErrorAction SilentlyContinue
    }
}

Remove-AgentToastAppRegistrations -AppIdPrefix "AgentToastNotify.Codex"
Remove-AgentToastBackups -BasePath $hooksPath
Remove-Item -LiteralPath (Join-Path $env:TEMP "agent-toast-codex.log") -Force -ErrorAction SilentlyContinue
Remove-AgentToastSharedTempIfUnused -HooksPath $hooksPath -SettingsPath $settingsPath

Write-Host "Uninstalled Codex Agent Toast hooks."
