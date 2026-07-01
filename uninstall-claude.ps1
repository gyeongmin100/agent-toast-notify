param(
    [string]$ClaudeHome = "$env:USERPROFILE\.claude",
    [string]$CodexHome = "$env:USERPROFILE\.codex",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "AgentToastNotify")
)

$ErrorActionPreference = "Stop"

$settingsPath = Join-Path $ClaudeHome "settings.json"
$hooksPath = Join-Path $CodexHome "hooks.json"
$backupPath = "$settingsPath.bak-agent-toast-uninstall"

Write-Host "Uninstalling Agent Toast Notify for Claude Code"
Write-Host "ClaudeHome: $ClaudeHome"
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

if (Test-Path -LiteralPath $settingsPath) {
    Copy-Item -Force $settingsPath $backupPath
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($settings.PSObject.Properties["hooks"]) {
        Remove-AgentToastHookGroups -HooksContainer $settings.hooks -EventName "Notification" -CommandPattern "claude-notify\.ps1.*permission-request"
        Remove-AgentToastHookGroups -HooksContainer $settings.hooks -EventName "Stop" -CommandPattern "claude-notify\.ps1.*stop"
        $json = $settings | ConvertTo-Json -Depth 20
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($settingsPath, $json, $utf8NoBom)
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

Write-Host "Uninstalled Claude Code Agent Toast hooks."
