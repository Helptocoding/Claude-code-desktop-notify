<div align="center">

<img src="https://raw.githubusercontent.com/Helptocoding/Claude-code-desktop-notify/main/assets/logo.png" alt="claude-code-desktop-notify logo" width="160" />

# claude-code-desktop-notify

**Notificaciones de escritorio para Claude Code**

Deja de mirar la terminal. Recibe una alerta cuando Claude necesita tu atención.

> Herramienta no oficial — no afiliada ni respaldada por Anthropic.

---

[Instalación](#instalación) • [Comandos](#comandos) • [Compatibilidad](#compatibilidad) • [Cómo funciona](#cómo-funciona) • [Solución de problemas](#solución-de-problemas)

![version](https://img.shields.io/npm/v/claude-code-desktop-notify?label=version&color=0e7fc0)
![license](https://img.shields.io/npm/l/claude-code-desktop-notify?label=license&color=22863a)
![node](https://img.shields.io/node/v/claude-code-desktop-notify?label=node&color=3d7a3d)
![platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20WSL-blueviolet)

</div>

---

## Instalación

```bash
npm install -g claude-code-desktop-notify
claude-code-desktop-notify
```

La segunda línea configura todo automáticamente: detecta tu OS, copia el script correcto, actualiza `~/.claude/settings.json` y muestra el resumen.

---

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

---

## Eventos cubiertos

| Evento | Cuándo dispara |
|--------|---------------|
| `permission_prompt` | Claude necesita que autorices una acción (escribir archivo, ejecutar comando, etc.) |
| `idle_prompt` | Claude lleva 60+ segundos esperando tu respuesta |

---

## Compatibilidad

| OS | Método |
|----|--------|
| **Windows** | PowerShell toast nativo (sin dependencias externas) |
| **macOS** | `osascript` (nativo) |
| **Linux** | `notify-send` (libnotify) |
| **WSL** | Llama a `powershell.exe` de Windows desde bash |

---

## Indicador en la terminal

Al recibir una notificación, el **título de la ventana del terminal** cambia automáticamente:

- `🔐 1 | Claude Code` — cuando Claude necesita autorización
- `⏳ 1 | Claude Code` — cuando Claude está esperando tu respuesta

El número sube con cada evento pendiente y se resetea cuando Claude termina la tarea. Visible en la barra de tareas de Windows Terminal.

Además, aparece un badge **cyan** `[NOTIFY]` en la barra inferior de Claude Code.

- Si ya tienes otra status line configurada, se **encadena** automáticamente sin reemplazarla.
- `claude-code-desktop-notify off` oculta el badge y las alertas; `on` lo restaura.
- Tras instalar o actualizar, **reinicia Claude Code** para ver el cambio.

---

## Cómo funciona

Claude Code tiene un sistema de hooks nativo. Este paquete registra un hook `Notification` en `~/.claude/settings.json` que ejecuta un script local cada vez que Claude necesita atención.

El hook recibe un JSON por stdin con el tipo de evento y el mensaje, y lo convierte en una notificación nativa del sistema operativo.

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

## Solución de problemas

### Windows: las notificaciones no aparecen

Verifica que las notificaciones estén habilitadas en **Configuración → Sistema → Notificaciones** y que **Claude Code Notifications** tenga permiso.

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

También puedes poner el nombre de cualquier `.wav` de `C:\Windows\Media` o la ruta completa a tu propio archivo.

Tras cambiar el JSON, prueba con `claude-code-desktop-notify test`.

### macOS: sin sonido o sin notificación

`osascript` necesita permisos de notificación en **Preferencias del Sistema → Notificaciones → Script Editor**.

El sonido se reproduce con `afplay` usando los sonidos del sistema en `/System/Library/Sounds/`. Si no escuchas nada, verifica que el volumen del sistema no esté en silencio y que Script Editor tenga permisos de notificación.

### WSL: no encuentra `powershell.exe`

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
# macOS / Linux
echo '{"notification_type":"permission_prompt","message":"Prueba manual","cwd":"/mi/proyecto"}' | ~/.claude/hooks/claude-code-desktop-notify.sh

# Windows
echo '{"notification_type":"permission_prompt","message":"Prueba manual","cwd":"C:\\proyecto"}' | powershell -File %USERPROFILE%\.claude\hooks\claude-code-desktop-notify.ps1
```

---

## Limitación conocida

El evento `AskUserQuestion` actualmente **no dispara** el hook `Notification` — es una limitación de Claude Code con un [feature request abierto](https://github.com/anthropics/claude-code/issues/13830). Los hooks de `permission_prompt` e `idle_prompt` cubren los casos más comunes.

---

## Licencia

MIT
