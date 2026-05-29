#!/usr/bin/env bash
# claude-code-desktop-notify — Resetea el contador del título de ventana.
# Se ejecuta con el hook Stop de Claude Code (cuando termina una tarea).

COUNT_FILE="$HOME/.claude/.notify-count"

if [ -f "$COUNT_FILE" ]; then
    rm -f "$COUNT_FILE"
fi

# Restaurar título de ventana a "Claude Code"
printf '\033]0;Claude Code\007'

exit 0
