param(
    [string]$Title = "Agent",
    [string]$Message = "",
    [string]$AppId = "Agent.Toast.Notify"
)

$ErrorActionPreference = "SilentlyContinue"
$NotifyLogPath = Join-Path $env:TEMP "agent-toast.log"
$LastHostHwndPath = Join-Path $env:TEMP "agent-toast-last-host-hwnd.txt"
$IconPath = Join-Path $PSScriptRoot "assets\agent-toast.png"

function Write-ToastLog {
    param([string]$Line)
    "$(Get-Date -Format 'HH:mm:ss.fff') $Line" | Add-Content -LiteralPath $NotifyLogPath
}

function Save-LastHostWindowHandle {
    param([Int64]$Handle)

    if ($Handle -gt 0) {
        Set-Content -LiteralPath $LastHostHwndPath -Value ([string]$Handle) -Encoding ASCII
        Write-ToastLog "SAVE lastHostHwnd=[$Handle]"
    }
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class AgentToastFgWin {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int procId);
}
"@

$hwnd = [AgentToastFgWin]::GetForegroundWindow()
$procId = 0
[AgentToastFgWin]::GetWindowThreadProcessId($hwnd, [ref]$procId) | Out-Null
$proc = Get-Process -Id $procId -ErrorAction SilentlyContinue

Write-ToastLog "START title=[$Title] message=[$Message] foregroundProc=[$($proc.ProcessName)] foregroundHwnd=[$hwnd]"

if ($proc.ProcessName -eq "Code" -or $proc.ProcessName -eq "Cursor") {
    Save-LastHostWindowHandle -Handle ([Int64]$hwnd)
    Write-ToastLog "EXIT foreground is host ($($proc.ProcessName))"
    exit 0
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class AgentToastHostWin {
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
"@

function Get-HostWindowHandle {
    $cur = $PID
    for ($i = 0; $i -lt 12; $i++) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$cur" -ErrorAction SilentlyContinue
        if (-not $p -or -not $p.ParentProcessId) { break }
        $cur = [int]$p.ParentProcessId
        $hp = Get-Process -Id $cur -ErrorAction SilentlyContinue
        if (-not $hp) { break }
        if ($hp.ProcessName -eq "explorer") { continue }
        $wh = [Int64]$hp.MainWindowHandle
        if ($wh -ne 0 -and [AgentToastHostWin]::IsWindowVisible([IntPtr]$wh)) { return $wh }
    }
    return 0
}

function Test-UsableWindowHandle {
    param([Int64]$Handle)

    if ($Handle -le 0) { return $false }
    $ptr = [IntPtr]::new($Handle)
    return [AgentToastHostWin]::IsWindow($ptr) -and [AgentToastHostWin]::IsWindowVisible($ptr)
}

function Get-LastFocusedWindowHandle {
    if (Test-Path -LiteralPath $LastHostHwndPath) {
        $stored = (Get-Content -LiteralPath $LastHostHwndPath -Raw -ErrorAction SilentlyContinue).Trim()
        $storedHandle = 0L
        if ([Int64]::TryParse($stored, [ref]$storedHandle) -and (Test-UsableWindowHandle -Handle $storedHandle)) {
            return $storedHandle
        }
    }

    $focusLog = Join-Path $env:TEMP "clifocus.log"
    if (-not (Test-Path -LiteralPath $focusLog)) { return 0 }

    $lines = Get-Content -LiteralPath $focusLog -Tail 80 -ErrorAction SilentlyContinue
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $line = [string]$lines[$i]
        $candidate = 0L
        if ($line -match "hwnd=([0-9]+)") {
            $candidate = [Int64]$Matches[1]
        } elseif ($line -match "clifocus://([0-9]+)") {
            $candidate = [Int64]$Matches[1]
        }

        if ($candidate -gt 0 -and (Test-UsableWindowHandle -Handle $candidate)) {
            return $candidate
        }
    }

    return 0
}

$hostHwnd = Get-HostWindowHandle
if ($hostHwnd -eq 0) {
    $hostHwnd = Get-LastFocusedWindowHandle
    Write-ToastLog "FALLBACK hostHwnd=[$hostHwnd]"
}

Save-LastHostWindowHandle -Handle $hostHwnd
$launchAttr = ""
if ($hostHwnd -ne 0) {
    $launchAttr = " activationType=`"protocol`" launch=`"clifocus://$hostHwnd`""
}
Write-ToastLog "TOAST hostHwnd=[$hostHwnd] launchAttr=[$launchAttr]"

$logoXml = ""
if (Test-Path -LiteralPath $IconPath) {
    $iconUri = ([System.Uri]$IconPath).AbsoluteUri
    $logoXml = "      <image placement=`"appLogoOverride`" src=`"$iconUri`" />"
}

[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null

$toastXml = @"
<toast$launchAttr>
  <visual>
    <binding template="ToastText02">
$logoXml
      <text id="1">$Title</text>
      <text id="2">$Message</text>
    </binding>
  </visual>
</toast>
"@

$xmlDoc = [Windows.Data.Xml.Dom.XmlDocument]::new()
$xmlDoc.LoadXml($toastXml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show(
    [Windows.UI.Notifications.ToastNotification]::new($xmlDoc)
)

[System.Media.SystemSounds]::Beep.Play()
