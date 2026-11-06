# claude-code-bootstrap: Windows installer (PowerShell 5.1+ and 7+)
#
# One line, no admin rights needed:
#   irm https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/install.ps1 | iex
#
# Options (environment variables, set before running):
#   $env:CCB_CHANNEL = "stable"        # stable (default) | latest | version number, e.g. 2.1.89
#   $env:CCB_EXTRAS  = "node,python"   # optional extra tools, installed with Scoop
#   $env:CCB_SKIP_GIT = "1"            # do not install Git for Windows
#
# Everything goes into your user profile. Safe to run again: it skips what is
# already installed and retries what failed.
#
# Messages are plain ASCII on purpose: Windows PowerShell 5.1 can mangle
# non-ASCII characters in scripts saved without a BOM.

function Install-ClaudeCodeBootstrap {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is 10x slower with the progress bar in PS 5.1

    $script:Problems = New-Object System.Collections.Generic.List[string]
    $Channel = if ($env:CCB_CHANNEL) { $env:CCB_CHANNEL } else { 'stable' }
    $Extras  = @()
    if ($env:CCB_EXTRAS) { $Extras = $env:CCB_EXTRAS.ToLower().Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } }

    $LocalBin  = Join-Path $env:USERPROFILE '.local\bin'
    $ClaudeExe = Join-Path $LocalBin 'claude.exe'
    $ScoopDir  = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    $ScoopCmd  = Join-Path $ScoopDir 'shims\scoop.cmd'
    $LogFile   = Join-Path $env:TEMP ("claude-code-bootstrap-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    function Say  ($m) { Write-Host "==> $m" -ForegroundColor Cyan }
    function Ok   ($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
    function Warn ($m) { Write-Host "  [WARN] $m" -ForegroundColor Yellow; $script:Problems.Add($m) }
    function Fail ($m) { Write-Host "  [FAIL] $m" -ForegroundColor Red;    $script:Problems.Add($m) }

    function Refresh-Path {
        $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path = (@($LocalBin, (Join-Path $ScoopDir 'shims'), $user, $machine) | Where-Object { $_ }) -join ';'
    }

    function Add-ToUserPath ($dir) {
        $user = [Environment]::GetEnvironmentVariable('Path', 'User')
        $parts = @()
        if ($user) { $parts = $user.Split(';') | Where-Object { $_ } }
        if ($parts -notcontains $dir) {
            [Environment]::SetEnvironmentVariable('Path', ((@($dir) + $parts) -join ';'), 'User')
            Ok "Added to user PATH: $dir"
        }
    }

    # Runs a downloaded .ps1 in a child process, so an 'exit' inside it cannot
    # close this window, and the execution policy cannot block it.
    function Invoke-RemoteScript ($url, [string[]]$scriptArgs) {
        $tmp = Join-Path $env:TEMP ("ccb-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        try {
            $psExe = (Get-Process -Id $PID).Path
            if (-not $psExe) { $psExe = 'powershell.exe' }
            # Out-Host: show the output and keep it out of this function's return value
            & $psExe -NoProfile -ExecutionPolicy Bypass -File $tmp @scriptArgs | Out-Host
            return $LASTEXITCODE
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    function Find-GitBash {
        $candidates = New-Object System.Collections.Generic.List[string]
        if ($env:CLAUDE_CODE_GIT_BASH_PATH) { $candidates.Add($env:CLAUDE_CODE_GIT_BASH_PATH) }
        $git = Get-Command git.exe -ErrorAction SilentlyContinue
        if ($git) {
            # ...\Git\cmd\git.exe or ...\Git\bin\git.exe  ->  ...\Git\bin\bash.exe
            $root = Split-Path (Split-Path $git.Source -Parent) -Parent
            $candidates.Add((Join-Path $root 'bin\bash.exe'))
            # Scoop shim: ...\scoop\shims\git.exe -> ...\scoop\apps\git\current\bin\bash.exe
            $candidates.Add((Join-Path $ScoopDir 'apps\git\current\bin\bash.exe'))
        }
        foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
            if ($base) { $candidates.Add((Join-Path $base 'Git\bin\bash.exe')) }
        }
        $candidates.Add((Join-Path $ScoopDir 'apps\git\current\bin\bash.exe'))
        foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path } }
        return $null
    }

    function Ensure-Scoop {
        if (Test-Path $ScoopCmd) { return $true }
        Say 'Installing Scoop (user-level package manager, no admin)'
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $a = @()
        if ($isAdmin) { $a = @('-RunAsAdmin') }
        try {
            $code = Invoke-RemoteScript 'https://get.scoop.sh' $a
            Refresh-Path
            if (Test-Path $ScoopCmd) { Ok 'Scoop installed'; return $true }
            Fail "Scoop installer finished with code $code but scoop was not found in $ScoopDir"
        } catch {
            Fail "Scoop install failed: $($_.Exception.Message)"
        }
        return $false
    }

    function Scoop-Install ($app) {
        if (-not (Ensure-Scoop)) { return $false }
        & $ScoopCmd install $app | Out-Host
        Refresh-Path
        return ($LASTEXITCODE -eq 0)
    }

    # ---------------------------------------------------------------- start
    try { Start-Transcript -Path $LogFile -ErrorAction Stop | Out-Null } catch { }

    Write-Host ''
    Write-Host '  claude-code-bootstrap for Windows' -ForegroundColor White
    Write-Host "  channel: $Channel   extras: $(if ($Extras) { $Extras -join ', ' } else { 'none' })"
    Write-Host ''

    # 1. System check -----------------------------------------------------
    Say 'Checking the system'
    $os = [Environment]::OSVersion.Version
    if ($os.Major -lt 10 -or ($os.Major -eq 10 -and $os.Build -lt 17763)) {
        Fail "Windows $os is too old. Claude Code needs Windows 10 1809 (build 17763) or newer."
        return
    }
    Ok "Windows build $($os.Build), PowerShell $($PSVersionTable.PSVersion), $env:PROCESSOR_ARCHITECTURE"

    # Old PowerShell defaults to TLS 1.0, which GitHub and claude.ai refuse.
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    # Corporate proxies: reuse the logged-in Windows identity.
    try {
        $proxy = [Net.WebRequest]::DefaultWebProxy
        if ($proxy) { $proxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials }
    } catch { }

    try {
        Invoke-WebRequest -Uri 'https://claude.ai/install.ps1' -UseBasicParsing -TimeoutSec 20 | Out-Null
        Ok 'Internet access to claude.ai works'
    } catch {
        Fail "Cannot reach https://claude.ai ($($_.Exception.Message)). Check internet or proxy (set HTTPS_PROXY)."
        return
    }

    # 2. Execution policy (only CurrentUser, no admin) ---------------------
    $eff = Get-ExecutionPolicy
    if ($eff -in @('Restricted', 'AllSigned', 'Undefined')) {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
            Ok "Execution policy for your user set to RemoteSigned (was $eff)"
        } catch {
            Warn "Could not change execution policy (probably locked by your organisation). Claude Code itself is an .exe and still works."
        }
    } else {
        Ok "Execution policy: $eff"
    }

    # 3. Git for Windows (provides Git Bash for Claude's Bash tool) --------
    Say 'Git for Windows'
    Refresh-Path
    $bash = Find-GitBash
    if (-not $bash -and $env:CCB_SKIP_GIT -ne '1') {
        Write-Host '  Git Bash not found, installing Git with Scoop (user-level)...'
        if (Scoop-Install 'git') { $bash = Find-GitBash } else { Fail 'scoop install git failed' }
    }
    if ($bash) {
        Ok "Git Bash: $bash"
        [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $bash, 'User')
        $env:CLAUDE_CODE_GIT_BASH_PATH = $bash
        Ok 'CLAUDE_CODE_GIT_BASH_PATH saved for your user'
    } else {
        Warn 'No Git Bash. Claude Code will still work, using PowerShell as its shell tool.'
    }

    # 4. Claude Code (official native installer) ---------------------------
    Say 'Claude Code'
    if (Test-Path $ClaudeExe) {
        Ok "Already installed: $ClaudeExe (it auto-updates; run 'claude update' to force)"
    } else {
        try {
            $code = Invoke-RemoteScript 'https://claude.ai/install.ps1' @($Channel)
            if (Test-Path $ClaudeExe) { Ok 'Claude Code installed' }
            else { Fail "Official installer finished with code $code but $ClaudeExe is missing" }
        } catch {
            Fail "Claude Code install failed: $($_.Exception.Message)"
        }
    }
    Write-Host '  (If the official installer mentioned PATH: the next line fixes it for you.)'
    Add-ToUserPath $LocalBin
    Refresh-Path

    # 5. Optional extras ----------------------------------------------------
    $map = @{ node = 'nodejs-lts'; nodejs = 'nodejs-lts'; python = 'python'; uv = 'uv'; ripgrep = 'ripgrep'; rg = 'ripgrep' }
    foreach ($e in $Extras) {
        Say "Extra: $e"
        if (-not $map.ContainsKey($e)) { Warn "Unknown extra '$e'. Known: node, python, uv, ripgrep"; continue }
        if (Scoop-Install $map[$e]) { Ok "$e installed" } else { Fail "$e install failed" }
    }

    # 6. Verification -------------------------------------------------------
    Say 'Verification'
    if (Test-Path $ClaudeExe) {
        $v = (& $ClaudeExe --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) { Ok "claude --version: $v" } else { Fail "claude --version failed: $v" }
    }
    $g = Get-Command git -ErrorAction SilentlyContinue
    if ($g) { Ok ((& git --version) | Out-String).Trim() }

    Write-Host ''
    if ($script:Problems.Count -eq 0) {
        Write-Host '  DONE. Everything is installed.' -ForegroundColor Green
        Write-Host ''
        Write-Host '  Next steps:'
        Write-Host '    1. Close this window and open a NEW PowerShell window.'
        Write-Host '    2. Go to your project folder:   cd C:\path\to\project'
        Write-Host '    3. Start Claude Code:           claude'
        Write-Host '       The first start opens the browser to log in.'
    } else {
        Write-Host "  FINISHED WITH $($script:Problems.Count) PROBLEM(S):" -ForegroundColor Yellow
        foreach ($p in $script:Problems) { Write-Host "    - $p" -ForegroundColor Yellow }
        Write-Host ''
        Write-Host '  You can run the same command again, it continues where it stopped.'
    }
    Write-Host "  Full log: $LogFile"
    Write-Host ''
    try { Stop-Transcript | Out-Null } catch { }
}

# Called on the last line, so a partially downloaded script does nothing.
Install-ClaudeCodeBootstrap
