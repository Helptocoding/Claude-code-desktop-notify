#!/usr/bin/env bash
# Ejecuta la status line previa (si existe) y luego el badge [NOTIFY].

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
BACKUP="$CLAUDE_DIR/.desktop-notify-statusline-prev.cmd"
BADGE="$CLAUDE_DIR/hooks/claude-code-desktop-notify-statusline.sh"
INPUT=$(cat)

if [ -f "$BACKUP" ] && [ ! -L "$BACKUP" ]; then
  PREV=$(head -c 4096 "$BACKUP" 2>/dev/null | tr -d '\r')
  if [ -n "$PREV" ]; then
    printf '%s' "$INPUT" | bash -lc "$PREV" 2>/dev/null
    printf ' '
  fi
fi

if [ -x "$BADGE" ]; then
  printf '%s' "$INPUT" | "$BADGE"
elif [ -f "$BADGE" ]; then
  printf '%s' "$INPUT" | bash "$BADGE"
fi
