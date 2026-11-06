# claude-code-bootstrap: remove Claude Code from Windows (user level).
# Keeps your settings and history in ~\.claude unless $env:CCB_PURGE = "1".
# Git and Scoop are left in place (other tools may use them).
#   irm https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/uninstall.ps1 | iex

function Uninstall-ClaudeCode {
    $ErrorActionPreference = 'Continue'
    $paths = @("$env:USERPROFILE\.local\bin\claude.exe", "$env:USERPROFILE\.local\share\claude")
    if ($env:CCB_PURGE -eq '1') { $paths += @("$env:USERPROFILE\.claude", "$env:USERPROFILE\.claude.json") }
    foreach ($p in $paths) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "  removed $p" -ForegroundColor Green }
    }
    [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $null, 'User')
    Write-Host '  Claude Code removed. Git and Scoop were left in place.'
    if ($env:CCB_PURGE -ne '1') { Write-Host '  Settings kept in ~\.claude (set $env:CCB_PURGE="1" to delete them too).' }
}
Uninstall-ClaudeCode
