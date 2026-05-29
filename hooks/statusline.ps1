# Badge [NOTIFY] para la status line de Claude Code (color cyan).
$Pkg = 'claude-code-desktop-notify'
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$Flag = Join-Path $ClaudeDir ".$Pkg-active"

if (-not (Test-Path -LiteralPath $Flag)) { exit 0 }

try {
    $Item = Get-Item -LiteralPath $Flag -Force -ErrorAction Stop
    if ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { exit 0 }
} catch { exit 0 }

$settingsPath = Join-Path $ClaudeDir 'settings.json'
try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $entry = $settings.hooks.Notification | Where-Object {
        $_.hooks | Where-Object { $_.command -like "*$Pkg*" -or $_.command -like '*claude-notify*' }
    } | Select-Object -First 1
    if ($entry -and $entry.disabled -eq $true) { exit 0 }
} catch {}

$Esc = [char]27
[Console]::Write("${Esc}[38;5;45m[NOTIFY]${Esc}[0m")
