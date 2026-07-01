# Agent Toast Notify

한국어 | [English](README.en.md)

에이전트에게 작업을 시켜두고 다른 일을 하다 보면, 작업이 완료되었는지 또는 승인이 필요한지 놓치기 쉽습니다.

Agent Toast Notify는 Codex 와 Claude Code의 작업완료나 권한승인 요청을 Windows 토스트 알림으로 알려주는 도구입니다.

## 기능

- 권한 승인이 필요할 때 `Approval required` 알림을 띄웁니다.
- 작업이 끝나고 agent가 멈췄을 때 `Task finished` 알림을 띄웁니다.
- 알림을 클릭하면 원래 작업하던 창으로 돌아갑니다.

## 지원 대상

- Windows에서 실행하는 Codex CLI
- Windows에서 실행하는 Claude Code CLI


## 설치

Codex CLI:

```powershell
irm https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main/install-codex.ps1 | iex
```

Claude Code CLI:

```powershell
irm https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main/install-claude.ps1 | iex
```

PowerShell에 위 명령어 중 필요한 것 하나를 복사해서 실행하면 됩니다.  
둘 다 쓰려면 설치 명령어 2개를 각각 실행하면 됩니다.

## 작동 방식

Agent Toast Notify는 Codex CLI와 Claude Code CLI의 hook 설정에 PowerShell 스크립트를 등록합니다.

권한 승인이 필요하거나 작업이 끝나면 CLI가 등록된 hook을 실행하고, 이 hook이 Windows 토스트 알림을 띄웁니다.

설치된 스크립트와 아이콘은 `%LOCALAPPDATA%\AgentToastNotify`에 저장됩니다.  
Codex는 `~/.codex/hooks.json`, Claude Code는 `~/.claude/settings.json`에 hook 실행 명령만 추가합니다.

주요 파일은 이렇게 나뉩니다.

- `codex-notify.ps1`, `claude-notify.ps1`: 각 CLI hook의 진입점
- `notify.ps1`: 토스트 알림 표시
- `clifocus.ps1`: 알림 클릭 시 원래 창으로 이동
- `agent-toast-48.png`: 알림 아이콘

## 제거

```powershell
irm https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main/uninstall-codex.ps1 | iex
irm https://raw.githubusercontent.com/gyeongmin100/agent-toast-notify/main/uninstall-claude.ps1 | iex
```

공용 스크립트 폴더는 Codex와 Claude Code 둘 다 더 이상 참조하지 않을 때만 제거됩니다.
