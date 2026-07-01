param(
    [Parameter(Position = 0)]
    [string]$Uri = ""
)

$ErrorActionPreference = "SilentlyContinue"
$LogPath = Join-Path $env:TEMP "clifocus.log"

function Write-FocusLog {
    param([string]$Message)
    "$(Get-Date -Format 'HH:mm:ss.fff') $Message" | Add-Content -LiteralPath $LogPath
}

Write-FocusLog "START uri=[$Uri]"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class CliFocusWin {
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int processId);
    [DllImport("kernel32.dll")] public static extern int GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(int idAttach, int idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

function Get-WindowHandleFromUri {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return [IntPtr]::Zero }

    $candidate = $Value.Trim()
    if ($candidate -match "^clifocus://([0-9]+)") {
        $candidate = $Matches[1]
    }

    $raw = 0L
    if (-not [Int64]::TryParse($candidate, [ref]$raw)) { return [IntPtr]::Zero }
    if ($raw -le 0) { return [IntPtr]::Zero }

    return [IntPtr]::new($raw)
}

$hwnd = Get-WindowHandleFromUri -Value $Uri
if ($hwnd -eq [IntPtr]::Zero -or -not [CliFocusWin]::IsWindow($hwnd)) {
    Write-FocusLog "EXIT invalid hwnd=[$hwnd]"
    exit 0
}

if ([CliFocusWin]::IsIconic($hwnd)) {
    [CliFocusWin]::ShowWindowAsync($hwnd, 9) | Out-Null
} else {
    [CliFocusWin]::ShowWindowAsync($hwnd, 5) | Out-Null
}

$firstSet = [CliFocusWin]::SetForegroundWindow($hwnd)
Start-Sleep -Milliseconds 30
$actualFg = [CliFocusWin]::GetForegroundWindow()
Write-FocusLog "SetForeground first=$firstSet actualFg=$actualFg hwnd=$hwnd"

if ($actualFg -ne $hwnd) {
    $foreground = [CliFocusWin]::GetForegroundWindow()
    $targetPid = 0
    $foregroundPid = 0
    $targetThread = [CliFocusWin]::GetWindowThreadProcessId($hwnd, [ref]$targetPid)
    $foregroundThread = [CliFocusWin]::GetWindowThreadProcessId($foreground, [ref]$foregroundPid)
    $currentThread = [CliFocusWin]::GetCurrentThreadId()

    [CliFocusWin]::AttachThreadInput($currentThread, $targetThread, $true) | Out-Null
    if ($foregroundThread -ne 0) {
        [CliFocusWin]::AttachThreadInput($currentThread, $foregroundThread, $true) | Out-Null
    }

    [CliFocusWin]::BringWindowToTop($hwnd) | Out-Null

    $HWND_TOPMOST = [IntPtr]::new(-1)
    $HWND_NOTOPMOST = [IntPtr]::new(-2)
    $SWP_NOSIZE = 0x0001
    $SWP_NOMOVE = 0x0002
    $SWP_SHOWWINDOW = 0x0040
    $flags = [uint32]($SWP_NOSIZE -bor $SWP_NOMOVE -bor $SWP_SHOWWINDOW)
    [CliFocusWin]::SetWindowPos($hwnd, $HWND_TOPMOST, 0, 0, 0, 0, $flags) | Out-Null
    [CliFocusWin]::SetWindowPos($hwnd, $HWND_NOTOPMOST, 0, 0, 0, 0, $flags) | Out-Null

    $secondSet = [CliFocusWin]::SetForegroundWindow($hwnd)
    Write-FocusLog "SetForeground second=$secondSet targetPid=$targetPid foregroundPid=$foregroundPid"

    if ($foregroundThread -ne 0) {
        [CliFocusWin]::AttachThreadInput($currentThread, $foregroundThread, $false) | Out-Null
    }
    [CliFocusWin]::AttachThreadInput($currentThread, $targetThread, $false) | Out-Null
}

exit 0

