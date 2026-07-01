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
    $content = Get-Content -LiteralPath $Path -Raw
    return $content -match "(codex-notify|claude-notify)\.ps1"
}

if (Test-Path -LiteralPath $hooksPath) {
    Copy-Item -Force $hooksPath $backupPath
    $hooks = Get-Content -LiteralPath $hooksPath -Raw | ConvertFrom-Json

    if ($hooks.PSObject.Properties["hooks"]) {
        Remove-AgentToastHookGroups -HooksContainer $hooks.hooks -EventName "PermissionRequest" -CommandPattern "codex-notify\.ps1.*permission-request"
        Remove-AgentToastHookGroups -HooksContainer $hooks.hooks -EventName "Stop" -CommandPattern "codex-notify\.ps1.*stop"
        $hooks | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $hooksPath -Encoding UTF8
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

Write-Host "Uninstalled Codex Agent Toast hooks."
