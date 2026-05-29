#!/usr/bin/env bash
# claude-code-desktop-notify — WSL notification hook

set -euo pipefail

INPUT=$(cat)
if [ -z "$INPUT" ]; then exit 0; fi

# ─── Chequear si está desactivado ─────────────────────────────────────────────
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
    DISABLED=$(python3 -c "
import json, sys
try:
    s = json.load(open('$SETTINGS'))
    entries = s.get('hooks', {}).get('Notification', [])
    entry = next((e for e in entries if any('claude-code-desktop-notify' in (h.get('command','')) or 'claude-notify' in (h.get('command','')) for h in e.get('hooks',[]))), None)
    print('true' if entry and entry.get('disabled') else 'false')
except:
    print('false')
" 2>/dev/null || echo 'false')
    if [ "$DISABLED" = "true" ]; then exit 0; fi
fi

# ─── Buscar powershell.exe de Windows ────────────────────────────────────────
POWERSHELL=""
for candidate in \
    "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" \
    "/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" \
    "$(command -v powershell.exe 2>/dev/null || echo '')"; do
    if [ -x "$candidate" ] 2>/dev/null; then
        POWERSHELL="$candidate"; break
    fi
done
POWERSHELL="${POWERSHELL:-powershell.exe}"

# ─── Ruta al script ps1 ───────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1_SCRIPT="$SCRIPT_DIR/claude-code-desktop-notify.ps1"

if [ ! -f "$PS1_SCRIPT" ]; then
    PKG_PS1="$SCRIPT_DIR/notify.ps1"
    [ -f "$PKG_PS1" ] && cp "$PKG_PS1" "$PS1_SCRIPT"
fi

WIN_PATH=""
command -v wslpath &>/dev/null && WIN_PATH=$(wslpath -w "$PS1_SCRIPT" 2>/dev/null || echo "")
[ -z "$WIN_PATH" ] && WIN_PATH=$(echo "$PS1_SCRIPT" | sed 's|^/mnt/\([a-z]\)/|\1:/|' | sed 's|/|\\|g')

echo "$INPUT" | "$POWERSHELL" \
    -ExecutionPolicy Bypass \
    -NonInteractive \
    -NoProfile \
    -File "$WIN_PATH" 2>/dev/null || true

# ─── Título de ventana con contador (afecta Windows Terminal) ─────────────────
COUNT_FILE="$HOME/.claude/.notify-count"
COUNT=0
if [ -f "$COUNT_FILE" ]; then
    VAL=$(cat "$COUNT_FILE" 2>/dev/null | tr -d '[:space:]')
    [[ "$VAL" =~ ^[0-9]+$ ]] && COUNT=$VAL
fi
COUNT=$((COUNT + 1))
printf '%s' "$COUNT" > "$COUNT_FILE"

NOTIF_TYPE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('notification_type',''))" 2>/dev/null || echo "")
ICON="⏳"
[[ "$NOTIF_TYPE" == "permission_prompt" ]] && ICON="🔐"
printf '\033]0;%s %d | Claude Code\007' "$ICON" "$COUNT"

exit 0
