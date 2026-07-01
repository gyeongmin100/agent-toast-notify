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
- Skips the notification if you're already looking at that window.

## Supported agents

- Codex CLI on Windows
- Claude Code CLI on Windows

## Install

Codex CLI:

```powershell
irm https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main/install-codex.ps1 | iex
```

Claude Code CLI:

```powershell
irm https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main/install-claude.ps1 | iex
```

Copy and run the command you need in PowerShell.  
To use both, run both install commands.

## How it works

Agent Toast Notify registers PowerShell scripts in the hook settings for Codex CLI and Claude Code CLI.

When approval is required or a task finishes, the CLI runs the registered hook, and that hook shows a Windows toast notification.

Installed scripts and the icon are stored in `%LOCALAPPDATA%\AgentToastNotify`.  
Codex only adds hook commands to `~/.codex/hooks.json`, and Claude Code only adds hook commands to `~/.claude/settings.json`.

Main files:

- `codex-notify.ps1`, `claude-notify.ps1`: entry points for each CLI hook
- `notify.ps1`: shows the toast notification
- `clifocus.ps1`: returns focus to the original window when you click the toast
- `agent-toast-48.png`: notification icon

## Uninstall

```powershell
irm https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main/uninstall-codex.ps1 | iex
irm https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main/uninstall-claude.ps1 | iex
```

The shared script folder is removed only when neither Codex nor Claude Code still references it.
