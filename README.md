# claude-code-desktop-notify

Notificaciones de escritorio para **Claude Code** — te avisa cuando necesita que autorices algo o está esperando tu respuesta.

> **Herramienta no oficial.** No está afiliada ni respaldada por Anthropic.

Deja de mirar la terminal. Trabaja en lo tuyo y recibe una alerta cuando Claude realmente te necesite.

## Instalación

```bash
npm install -g claude-code-desktop-notify
# o
pnpm add -g claude-code-desktop-notify
```

El `postinstall` configura todo automáticamente: detecta tu OS, copia el script correcto y actualiza `~/.claude/settings.json`.

## Eventos cubiertos

| Evento | Cuándo dispara |
|--------|---------------|
| `permission_prompt` | Claude necesita que autorices una acción (escribir archivo, ejecutar comando, etc.) |
| `idle_prompt` | Claude lleva 60+ segundos esperando tu respuesta |

## Compatibilidad

| OS | Metodo |
|----|--------|
| **Windows** | PowerShell toast nativo (sin dependencias externas) |
| **macOS** | `osascript` (nativo) |
| **Linux** | `notify-send` (libnotify) |
| **WSL** | Llama a `powershell.exe` de Windows desde bash |

## Comandos

```bash
# Activar / desactivar (sin desinstalar)
claude-code-desktop-notify off
claude-code-desktop-notify on

# Ver estado de la instalación
claude-code-desktop-notify status

# Enviar notificación de prueba
claude-code-desktop-notify test

# Reinstalar / reparar configuración
claude-code-desktop-notify setup

# Desinstalar (limpia settings.json automáticamente)
npm remove -g claude-code-desktop-notify
```

## Indicador [NOTIFY] en Claude Code

Al instalar, aparece un badge **cyan** `[NOTIFY]` en la barra inferior de Claude Code.

- Si ya tienes otra status line configurada, se **encadena** automáticamente sin reemplazarla.
- `claude-code-desktop-notify off` oculta el badge y las alertas; `on` lo restaura.
- Tras instalar o actualizar, **reinicia Claude Code** para ver el cambio.

## Cómo funciona

Claude Code tiene un sistema de hooks nativo. Este paquete registra un hook `Notification` en `~/.claude/settings.json` que ejecuta un script local cada vez que Claude necesita atención.

El hook recibe un JSON por stdin con el tipo de evento y el mensaje, y lo convierte en una notificación nativa del sistema operativo.

```json
// Lo que agrega a ~/.claude/settings.json
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

## Solución de problemas

### Windows: las notificaciones no aparecen

Verifica que las notificaciones esten habilitadas en **Configuración → Sistema → Notificaciones** y que **Claude Code Notifications** tenga permiso.

### Windows: personalizar el sonido

Por defecto usa sonidos suaves de `C:\Windows\Media` (nudge al pedir permiso, chimes al esperar respuesta).

Crea `~/.claude/desktop-notify-sounds.json` con rutas completas o alias:

```json
{
  "permission_prompt": "nudge",
  "idle_prompt": "chimes",
  "auth_success": "ding",
  "default": "notify"
}
```

**Alias disponibles:** `chimes`, `ding`, `notify`, `nudge`, `messaging`, `email`, `balloon`, `default`, `generic`, `exclamation`, `error`, `calendar`

Tambien puedes poner el nombre de cualquier `.wav` de `C:\Windows\Media` o la ruta completa a tu propio archivo, por ejemplo `"C:\\Users\\TU\\Music\\alerta.wav"`.

Tras cambiar el JSON, prueba con `claude-code-desktop-notify test`.

### macOS: sin sonido o sin notificación

`osascript` necesita permisos de notificación en **Preferencias del Sistema → Notificaciones → Script Editor**.

### WSL: no encuentra `powershell.exe`

Asegúrate de tener acceso a Windows desde WSL. Prueba:
```bash
which powershell.exe
# Debe retornar algo como /mnt/c/Windows/System32/...
```

Si usas Git Bash o MSYS2, agrega PowerShell al PATH:
```bash
export PATH="/c/Windows/System32/WindowsPowerShell/v1.0:$PATH"
```

### Verificar que el hook funciona

```bash
# Simular el evento manualmente
echo '{"notification_type":"permission_prompt","message":"Prueba manual","cwd":"/mi/proyecto"}' | ~/.claude/hooks/claude-code-desktop-notify.sh
# o en Windows:
echo '{"notification_type":"permission_prompt","message":"Prueba manual","cwd":"C:\\proyecto"}' | powershell -File %USERPROFILE%\.claude\hooks\claude-code-desktop-notify.ps1
```

## Limitación conocida

El evento `AskUserQuestion` (cuando Claude hace una pregunta interactiva) actualmente **no dispara** el hook `Notification` — es una limitación de Claude Code que tiene un [feature request abierto](https://github.com/anthropics/claude-code/issues/13830). Los hooks de `permission_prompt` e `idle_prompt` cubren los casos más comunes.

## Licencia

MIT
