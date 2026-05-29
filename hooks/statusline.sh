#!/usr/bin/env bash
# Badge [NOTIFY] para la status line de Claude Code.

PKG="claude-code-desktop-notify"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
FLAG="$CLAUDE_DIR/.$PKG-active"

[ -L "$FLAG" ] && exit 0
[ ! -f "$FLAG" ] && exit 0

SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
  DISABLED=$(python3 -c "
import json
try:
    s = json.load(open('$SETTINGS'))
    entries = s.get('hooks', {}).get('Notification', [])
    entry = next((e for e in entries if any('$PKG' in (h.get('command','')) or 'claude-notify' in (h.get('command','')) for h in e.get('hooks',[]))), None)
    print('true' if entry and entry.get('disabled') else 'false')
except:
    print('false')
" 2>/dev/null || echo 'false')
  [ "$DISABLED" = "true" ] && exit 0
fi

printf '\033[38;5;45m[NOTIFY]\033[0m'
