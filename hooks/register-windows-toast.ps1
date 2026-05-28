# Registra un AppUserModelID para que Windows muestre toasts de apps no empaquetadas.
param(
    [string]$AppId = 'ClaudeCode.DesktopNotify',
    [string]$DisplayName = 'Claude Code Notifications'
)

$ErrorActionPreference = 'Stop'

$regPath = "HKCU:\Software\Classes\AppUserModelId\$AppId"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
New-ItemProperty -Path $regPath -Name DisplayName -Value $DisplayName -PropertyType String -Force | Out-Null

$programsDir = [Environment]::GetFolderPath('Programs')
if (-not (Test-Path $programsDir)) {
    New-Item -ItemType Directory -Path $programsDir -Force | Out-Null
}

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
}

# Asignar AppUserModelID al acceso directo (requerido para toasts en Win10/11)
try {
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.NameSpace($programsDir)
    $item = $folder.ParseName('Claude Code Notifications.lnk')
    if ($item) {
        $item.Properties.Item('System.AppUserModel.ID').Value = $AppId
    }
} catch {
    # Si falla la propiedad COM, el registro suele bastar en muchas instalaciones
}

exit 0
