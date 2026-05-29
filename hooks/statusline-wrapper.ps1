# Ejecuta la status line previa (si existe) y luego el badge [NOTIFY].
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$Backup = Join-Path $ClaudeDir '.desktop-notify-statusline-prev.cmd'
$Badge = Join-Path $ClaudeDir "hooks\claude-code-desktop-notify-statusline.ps1"

if (Test-Path -LiteralPath $Backup) {
    try {
        $prev = (Get-Content -LiteralPath $Backup -Raw -ErrorAction Stop).Trim()
        if ($prev.Length -gt 0) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'cmd.exe'
            $psi.Arguments = "/c $prev"
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            $p = [System.Diagnostics.Process]::Start($psi)
            $stdin = [System.Console]::In.ReadToEnd()
            $p.StandardInput.Write($stdin)
            $p.StandardInput.Close()
            $out = $p.StandardOutput.ReadToEnd()
            $p.WaitForExit(1500)
            if ($out) { [Console]::Write($out.TrimEnd()) }
            [Console]::Write(' ')
        }
    } catch {}
}

if (Test-Path -LiteralPath $Badge) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Badge
}
