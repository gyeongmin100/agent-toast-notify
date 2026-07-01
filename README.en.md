# Agent Toast Notify

[한국어](README.md) | English

When you hand work off to an agent and switch to something else, it is easy to
miss the moment when the task finishes or needs approval.

Agent Toast Notify is a tool that sends Windows toast notifications when Codex
or Claude Code finishes a task or asks for approval.

## What it does

- Shows `Approval required` when approval is needed.
- Shows `Task finished` when the task is done and the agent stops.
- Returns you to the original working window when you click the notification.

## Supported agents

- Codex CLI on Windows
- Claude Code CLI on Windows

## Install

Codex CLI:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-codex.ps1
```

Claude Code CLI:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-claude.ps1
```

To use both, run both installers.

## How it works

Agent Toast Notify registers PowerShell scripts in the hook settings for Codex CLI and Claude Code CLI.

When approval is required or a task finishes, the CLI runs the registered hook, and that hook shows a Windows toast notification.

Installed scripts and the icon are stored in `%LOCALAPPDATA%\AgentToastNotify`.  
Codex only adds hook commands to `~/.codex/hooks.json`, and Claude Code only adds hook commands to `~/.claude/settings.json`.

Main files:

- `codex-notify.ps1`, `claude-notify.ps1`: entry points for each CLI hook
- `notify.ps1`: shows the toast notification
- `clifocus.ps1`: returns focus to the original window when you click the toast
- `agent-toast.png`: notification icon

## Uninstall

```powershell
.\uninstall-codex.ps1
.\uninstall-claude.ps1
```

The shared script folder is removed only when neither Codex nor Claude Code still references it.
