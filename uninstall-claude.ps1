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
    $content = Get-Content -LiteralPath $Path -Raw
    return $content -match "(codex-notify|claude-notify)\.ps1"
}

if (Test-Path -LiteralPath $settingsPath) {
    Copy-Item -Force $settingsPath $backupPath
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json

    if ($settings.PSObject.Properties["hooks"]) {
        Remove-AgentToastHookGroups -HooksContainer $settings.hooks -EventName "Notification" -CommandPattern "claude-notify\.ps1.*permission-request"
        Remove-AgentToastHookGroups -HooksContainer $settings.hooks -EventName "Stop" -CommandPattern "claude-notify\.ps1.*stop"
        $settings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
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

Write-Host "Uninstalled Claude Code Agent Toast hooks."
