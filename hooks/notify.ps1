# claude-code-desktop-notify — Windows Toast Notification Hook

param()

$ToastAppId = 'ClaudeCode.DesktopNotify'

function Register-ToastApp {
    param(
        [string]$AppId = $ToastAppId,
        [string]$DisplayName = 'Claude Code Notifications'
    )
    $regPath = "HKCU:\Software\Classes\AppUserModelId\$AppId"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    New-ItemProperty -Path $regPath -Name DisplayName -Value $DisplayName -PropertyType String -Force | Out-Null

    $programsDir = [Environment]::GetFolderPath('Programs')
    $shortcutPath = Join-Path $programsDir 'Claude Code Notifications.lnk'
    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

    if (-not (Test-Path $shortcutPath)) {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $psExe
        $shortcut.Arguments = '-NoLogo -NonInteractive -NoProfile -WindowStyle Hidden -Command exit'
        $shortcut.WorkingDirectory = $env:USERPROFILE
        $shortcut.Description = $DisplayName
        $shortcut.Save()
        try {
            $shell = New-Object -ComObject Shell.Application
            $folder = $shell.NameSpace($programsDir)
            $item = $folder.ParseName('Claude Code Notifications.lnk')
            if ($item) { $item.Properties.Item('System.AppUserModel.ID').Value = $AppId }
        } catch {}
    }
}

function Get-SoundConfig {
    $path = Join-Path $env:USERPROFILE '.claude\desktop-notify-sounds.json'
    if (-not (Test-Path $path)) { return $null }
    try {
        return Get-Content $path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Resolve-SoundFile {
    param([string]$Spec)

    if ([string]::IsNullOrWhiteSpace($Spec)) { return $null }

  $aliases = @{
    chimes     = 'chimes.wav'
    ding       = 'ding.wav'
    notify     = 'notify.wav'
    nudge      = 'Windows Message Nudge.wav'
    messaging  = 'Windows Notify Messaging.wav'
    email      = 'Windows Notify Email.wav'
    balloon    = 'Windows Balloon.wav'
    default    = 'Windows Notify System Generic.wav'
    generic    = 'Windows Notify.wav'
    exclamation = 'Windows Exclamation.wav'
    error      = 'Windows Error.wav'
    calendar   = 'Windows Notify Calendar.wav'
  }

    if ($aliases.ContainsKey($Spec.ToLower())) {
        $Spec = $aliases[$Spec.ToLower()]
    }

    if (Test-Path -LiteralPath $Spec) { return (Resolve-Path -LiteralPath $Spec).Path }

    $mediaFile = Join-Path $env:WINDIR "Media\$Spec"
    if (Test-Path -LiteralPath $mediaFile) { return $mediaFile }

    return $null
}

function Get-DefaultSoundSpec {
    param([string]$NotifType)

    switch ($NotifType) {
        'permission_prompt' { return 'nudge' }
        'idle_prompt'       { return 'chimes' }
        'auth_success'      { return 'ding' }
        default             { return 'notify' }
    }
}

function Play-NotificationSound {
    param([string]$NotifType)

    $config = Get-SoundConfig
    $spec = $null
    if ($config) {
        $spec = $config.$NotifType
        if (-not $spec) { $spec = $config.default }
    }
    if (-not $spec) { $spec = Get-DefaultSoundSpec -NotifType $NotifType }

    $wavPath = Resolve-SoundFile -Spec $spec
    if (-not $wavPath) { return }

    # PlaySound vive en winmm.dll (no user32). SYNC evita que el proceso termine antes de oír el audio.
    try {
        if (-not ('WinMmSound' -as [type])) {
            Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WinMmSound {
  [DllImport("winmm.dll", SetLastError = true, CharSet = CharSet.Auto)]
  public static extern bool PlaySound(string pszSound, IntPtr hmod, uint fdwFlag);
}
'@ | Out-Null
        }

        $flags = [uint32]0x00020000  # SND_FILENAME | SND_SYNC
        if ([WinMmSound]::PlaySound($wavPath, [IntPtr]::Zero, $flags)) { return }
    } catch {}

    try {
        $player = New-Object System.Media.SoundPlayer $wavPath
        $player.PlaySync()
    } catch {
        try {
            [void][Console]::Beep(740, 200)
        } catch {}
    }
}

function Show-WinRTToast {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Subtitle,
        [string]$Sound
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    $safeTitle    = [System.Security.SecurityElement]::Escape($Title)
    $safeMessage  = [System.Security.SecurityElement]::Escape($Message)
    $safeSubtitle = [System.Security.SecurityElement]::Escape($Subtitle)
    $subtitleXml  = if ($Subtitle) { "<text>$safeSubtitle</text>" } else { '' }

    $toastXml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$safeTitle</text>
      $subtitleXml
      <text>$safeMessage</text>
    </binding>
  </visual>
  <audio silent="true"/>
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($ToastAppId)
    $notifier.Show($toast)
}

function Show-FallbackToast {
    param(
        [string]$Title,
        [string]$Message,
        [string]$NotifType = 'default'
    )

    Play-NotificationSound -NotifType $NotifType

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.Visible = $true
    $notify.BalloonTipTitle = $Title
    $notify.BalloonTipText = $Message
    $notify.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $notify.ShowBalloonTip(10000)
    Start-Sleep -Seconds 3
    $notify.Dispose()
}

# ─── Título de ventana con contador ──────────────────────────────────────────
function Update-TerminalTitle {
    param([string]$NotifType)
    try {
        $countFile = Join-Path $env:USERPROFILE '.claude\.notify-count'
        $count = 0
        if (Test-Path -LiteralPath $countFile) {
            $val = (Get-Content -LiteralPath $countFile -Raw -ErrorAction SilentlyContinue).Trim()
            if ($val -match '^\d+$') { $count = [int]$val }
        }
        $count++
        Set-Content -LiteralPath $countFile -Value "$count" -NoNewline -ErrorAction SilentlyContinue

        $icon = if ($NotifType -eq 'permission_prompt') { '🔐' } else { '⏳' }
        $newTitle = "$icon $count | Claude Code"
        # Secuencia de escape OSC 0 para cambiar título de ventana
        [Console]::Write("`e]0;$newTitle`a")
    } catch {}
}

# ─── Leer stdin ───────────────────────────────────────────────────────────────
$rawInput = $null
try {
    $lines = @()
    while ($null -ne ($line = [Console]::In.ReadLine())) {
        $lines += $line
    }
    $rawInput = $lines -join "`n"
} catch { exit 0 }

if (-not $rawInput -or $rawInput.Trim() -eq '') { exit 0 }

try {
    $data = $rawInput | ConvertFrom-Json
} catch { exit 0 }

$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $entry = $settings.hooks.Notification | Where-Object {
        $_.hooks | Where-Object { $_.command -like '*claude-code-desktop-notify*' -or $_.command -like '*claude-notify*' }
    } | Select-Object -First 1
    if ($entry -and $entry.disabled -eq $true) { exit 0 }
} catch {}

$notifType = $data.notification_type
$message   = if ($data.message) { $data.message } else { 'Claude necesita tu atención' }
$cwd       = if ($data.cwd) { Split-Path $data.cwd -Leaf } else { '' }

if ($message.Length -gt 120) { $message = $message.Substring(0, 117) + '...' }

switch ($notifType) {
    'permission_prompt' {
        $title = 'Claude Code - Autorizacion requerida'
        $sound = 'ms-winsoundevent:Notification.SMS'
    }
    'idle_prompt' {
        $title = 'Claude Code - Esperando respuesta'
        $sound = 'ms-winsoundevent:Notification.Reminder'
    }
    'auth_success' {
        $title = 'Claude Code - Autenticado'
        $sound = 'ms-winsoundevent:Notification.Default'
    }
    default {
        $title = 'Claude Code'
        $sound = 'ms-winsoundevent:Notification.Default'
    }
}

$subtitle = if ($cwd) { "Proyecto: $cwd" } else { '' }

Register-ToastApp
Update-TerminalTitle -NotifType $notifType

try {
    Show-WinRTToast -Title $title -Message $message -Subtitle $subtitle -Sound $sound
    Play-NotificationSound -NotifType $notifType
} catch {
    try {
        Show-FallbackToast -Title $title -Message $message -NotifType $notifType
    } catch {
        Play-NotificationSound -NotifType $notifType
        Write-Host "[$title] $message"
    }
}

exit 0
