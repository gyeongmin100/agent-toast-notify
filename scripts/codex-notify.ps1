param(
    [string]$Event = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = "SilentlyContinue"
"$(Get-Date -Format 'HH:mm:ss.fff') EVENT=[$Event] ARGS=[$RemainingArgs]" | Add-Content "$env:TEMP\agent-toast-codex.log"

$notifyScript = Join-Path $PSScriptRoot "notify.ps1"
$messagePermissionRequired = "Approval required"
$messageStop = "Task finished"

function Send-AgentToast {
    param([string]$Message)

    if (Test-Path -LiteralPath $notifyScript) {
        & $notifyScript -Title "Codex" -Message $Message -AppId "Codex"
    }
}

switch ($Event) {
    "permission-request" { Send-AgentToast -Message $messagePermissionRequired }
    "stop"               { Send-AgentToast -Message $messageStop }
}

exit 0
