<div align="center">

<img src="https://raw.githubusercontent.com/Helptocoding/Claude-code-desktop-notify/main/assets/logo.png" alt="claude-code-desktop-notify logo" width="160" />

# claude-code-desktop-notify

**Desktop notifications for Claude Code**

Stop watching the terminal. Get alerted when Claude needs your attention.

> Unofficial tool — not affiliated with or endorsed by Anthropic.

---

[Installation](#installation) • [Commands](#commands) • [Compatibility](#compatibility) • [How it works](#how-it-works) • [Troubleshooting](#troubleshooting)

![version](https://img.shields.io/npm/v/claude-code-desktop-notify?label=version&color=0e7fc0)
![license](https://img.shields.io/npm/l/claude-code-desktop-notify?label=license&color=22863a)
![node](https://img.shields.io/node/v/claude-code-desktop-notify?label=node&color=3d7a3d)
![platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20WSL-blueviolet)

</div>

---

## Installation

```bash
npm install -g claude-code-desktop-notify
```

The `postinstall` script automatically configures everything: detects your OS, copies the right script, and updates `~/.claude/settings.json`.

---

## Commands

```bash
# Enable / disable (without uninstalling)
claude-code-desktop-notify off
claude-code-desktop-notify on

# Check installation status
claude-code-desktop-notify status

# Send test notification
claude-code-desktop-notify test

# Reinstall / repair configuration
claude-code-desktop-notify setup

# Uninstall (automatically cleans settings.json)
npm remove -g claude-code-desktop-notify
```

---

## Covered events

| Event | When it triggers |
|--------|---------------|
| `permission_prompt` | Claude needs you to authorize an action (write file, run command, etc.) |
| `idle_prompt` | Claude has been waiting 60+ seconds for your response |

---

## Compatibility

| OS | Method |
|----|--------|
| **Windows** | Native PowerShell toast (no external dependencies) |
| **macOS** | `osascript` (native) |
| **Linux** | `notify-send` (libnotify) |
| **WSL** | Calls Windows `powershell.exe` from bash |

---

## Terminal indicator

When a notification arrives, the **terminal window title** changes automatically:

- `🔐 1 | Claude Code` — when Claude needs authorization
- `⏳ 1 | Claude Code` — when Claude is waiting for your response

The number increments with each pending event and resets when Claude finishes the task. Visible in the Windows Terminal taskbar.

Additionally, a **cyan** `[NOTIFY]` badge appears in Claude Code's status bar.

- If you already have another status line configured, it **chains** automatically without replacing it.
- `claude-code-desktop-notify off` hides the badge and alerts; `on` restores them.
- After installing or updating, **restart Claude Code** to see the change.

---

## How it works

Claude Code has a native hook system. This package registers a `Notification` hook in `~/.claude/settings.json` that executes a local script whenever Claude needs attention.

The hook receives a JSON via stdin with the event type and message, and converts it into a native OS notification.

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt|idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "...",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

---

## Troubleshooting

### Windows: notifications don't appear

Verify that notifications are enabled in **Settings → System → Notifications** and that **Claude Code Notifications** has permission.

### Windows: customize sound

By default it uses soft sounds from `C:\Windows\Media` (nudge for permission requests, chimes for waiting).

Create `~/.claude/desktop-notify-sounds.json` with full paths or aliases:

```json
{
  "permission_prompt": "nudge",
  "idle_prompt": "chimes",
  "auth_success": "ding",
  "default": "notify"
}
```

**Available aliases:** `chimes`, `ding`, `notify`, `nudge`, `messaging`, `email`, `balloon`, `default`, `generic`, `exclamation`, `error`, `calendar`

You can also use any `.wav` filename from `C:\Windows\Media` or the full path to your own file.

After changing the JSON, test with `claude-code-desktop-notify test`.

### macOS: no sound or notification

`osascript` needs notification permissions in **System Preferences → Notifications → Script Editor**.

Sound is played with `afplay` using system sounds from `/System/Library/Sounds/`. If you don't hear anything, verify that system volume isn't muted and that Script Editor has notification permissions.

### WSL: can't find `powershell.exe`

```bash
which powershell.exe
# Should return something like /mnt/c/Windows/System32/...
```

If using Git Bash or MSYS2, add PowerShell to PATH:

```bash
export PATH="/c/Windows/System32/WindowsPowerShell/v1.0:$PATH"
```

### Verify the hook works

```bash
# macOS / Linux
echo '{"notification_type":"permission_prompt","message":"Manual test","cwd":"/my/project"}' | ~/.claude/hooks/claude-code-desktop-notify.sh

# Windows
echo '{"notification_type":"permission_prompt","message":"Manual test","cwd":"C:\\project"}' | powershell -File %USERPROFILE%\.claude\hooks\claude-code-desktop-notify.ps1
```

---

## Known limitation

The `AskUserQuestion` event currently **does not trigger** the `Notification` hook — it's a Claude Code limitation with an [open feature request](https://github.com/anthropics/claude-code/issues/13830). The `permission_prompt` and `idle_prompt` hooks cover the most common cases.

---

## License

MIT
