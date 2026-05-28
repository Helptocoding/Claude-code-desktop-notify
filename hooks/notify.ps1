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

function Play-NotificationSound {
    param([string]$NotifType)

  $played = $false
  try {
    if (-not ('NativeSound' -as [type])) {
      Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NativeSound {
  [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
  public static extern bool PlaySound(string pszSound, IntPtr hmod, uint fdwFlag);
}
'@ | Out-Null
    }

    $asyncAlias = [uint32]0x00010001  # SND_ASYNC | SND_ALIAS
    switch ($NotifType) {
      'permission_prompt' {
        [void][NativeSound]::PlaySound('SystemExclamation', [IntPtr]::Zero, $asyncAlias)
        Start-Sleep -Milliseconds 200
        [void][NativeSound]::PlaySound('SystemHand', [IntPtr]::Zero, $asyncAlias)
      }
      'idle_prompt'       { [void][NativeSound]::PlaySound('SystemAsterisk', [IntPtr]::Zero, $asyncAlias) }
      'auth_success'      { [void][NativeSound]::PlaySound('SystemDefault', [IntPtr]::Zero, $asyncAlias) }
      default             { [void][NativeSound]::PlaySound('SystemDefault', [IntPtr]::Zero, $asyncAlias) }
    }
    $played = $true
  } catch {}

  if ($played) { return }

  try {
    switch ($NotifType) {
      'permission_prompt' {
        [void][Console]::Beep(880, 180)
        Start-Sleep -Milliseconds 90
        [void][Console]::Beep(1100, 220)
      }
      'idle_prompt'       { [void][Console]::Beep(740, 200) }
      default             { [void][Console]::Beep(600, 150) }
    }
  } catch {}
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
  <audio src="$Sound" silent="false" loop="false"/>
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
        $title = 'Claude Code - Autorización requerida'
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
