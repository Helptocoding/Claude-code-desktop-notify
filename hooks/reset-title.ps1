# claude-code-desktop-notify — Resetea el contador del título de ventana.
# Se ejecuta con el hook Stop de Claude Code (cuando termina una tarea).

$countFile = Join-Path $env:USERPROFILE '.claude\.notify-count'

try {
    if (Test-Path -LiteralPath $countFile) {
        Remove-Item -LiteralPath $countFile -Force -ErrorAction SilentlyContinue
    }
    # Restaurar título de ventana a "Claude Code"
    [Console]::Write("`e]0;Claude Code`a")
} catch {}

exit 0
