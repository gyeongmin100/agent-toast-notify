param(
    [string]$Event = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = "SilentlyContinue"

$notifyScript = Join-Path $PSScriptRoot "notify.ps1"
$messagePermissionRequired = "Approval required"
$messageStopped = "Task finished"

function Send-AgentToast {
    param([string]$Message)

    if (Test-Path -LiteralPath $notifyScript) {
        & $notifyScript -Title "Claude Code" -Message $Message -AppId "ClaudeCode.Notify"
    }
}

switch ($Event) {
    "permission-request" { Send-AgentToast -Message $messagePermissionRequired }
    "stop"               { Send-AgentToast -Message $messageStopped }
}

exit 0
