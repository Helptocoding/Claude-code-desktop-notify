#!/usr/bin/env bash
# claude-code-desktop-notify — macOS / Linux notification hook

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

# ─── Parsear JSON ─────────────────────────────────────────────────────────────
parse_json() {
    python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('$1', ''))
except:
    print('')
" <<< "$INPUT"
}

NOTIF_TYPE=$(parse_json 'notification_type')
MESSAGE=$(parse_json 'message')
CWD=$(parse_json 'cwd')

if [ ${#MESSAGE} -gt 120 ]; then MESSAGE="${MESSAGE:0:117}..."; fi
MESSAGE=${MESSAGE:-"Claude necesita tu atención"}
PROJECT=$(basename "$CWD" 2>/dev/null || echo "")

case "$NOTIF_TYPE" in
    permission_prompt) TITLE="🔐 Claude Code — Autorizacion requerida"; SOUND="Ping"    ;;
    idle_prompt)       TITLE="⏳ Claude Code — Esperando respuesta";      SOUND="Tink"    ;;
    auth_success)      TITLE="✅ Claude Code — Autenticado";               SOUND="Glass"   ;;
    *)                 TITLE="Claude Code";                                SOUND="Default" ;;
esac

SUBTITLE=${PROJECT:+"Proyecto: $PROJECT"}

if [[ "$(uname)" == "Darwin" ]]; then
    SAFE_TITLE="${TITLE//\"/\\\"}"
    SAFE_MSG="${MESSAGE//\"/\\\"}"
    SAFE_SUBTITLE="${SUBTITLE//\"/\\\"}"
    SCRIPT="display notification \"$SAFE_MSG\" with title \"$SAFE_TITLE\""
    [ -n "$SUBTITLE" ] && SCRIPT="display notification \"$SAFE_MSG\" with title \"$SAFE_TITLE\" subtitle \"$SAFE_SUBTITLE\""
    SCRIPT="$SCRIPT sound name \"$SOUND\""
    osascript -e "$SCRIPT" 2>/dev/null || true
else
    URGENCY="normal"
    [[ "$NOTIF_TYPE" == "permission_prompt" ]] && URGENCY="critical"
    if command -v notify-send &>/dev/null; then
        notify-send --urgency="$URGENCY" --expire-time=8000 "$TITLE" "$MESSAGE" 2>/dev/null || true
    else
        echo -e "\033[1;33m[$TITLE]\033[0m $MESSAGE"
    fi
    case "$NOTIF_TYPE" in
        permission_prompt) ICON="dialog-warning" ;;
        idle_prompt)       ICON="message-new-instant" ;;
        *)                 ICON="complete" ;;
    esac
    if command -v canberra-gtk-play &>/dev/null; then
        canberra-gtk-play -i "$ICON" 2>/dev/null &
    elif command -v paplay &>/dev/null; then
        for f in "/usr/share/sounds/freedesktop/stereo/${ICON}.oga" \
                 "/usr/share/sounds/freedesktop/stereo/${ICON}.ogg"; do
            [ -f "$f" ] && paplay "$f" 2>/dev/null & break
        done
    fi
fi

exit 0
