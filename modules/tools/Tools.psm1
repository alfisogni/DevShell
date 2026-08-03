#requires -Version 7.0
# tools — catálogo y ensure suave de CLIs externas.

$script:DsToolCatalog = [ordered]@{
    git         = @{ Commands = @('git');  Description = 'Version control' }
    fzf         = @{ Commands = @('fzf');  Description = 'Fuzzy finder' }
    rg          = @{ Commands = @('rg');   Description = 'ripgrep search' }
    fd          = @{ Commands = @('fd', 'fd.exe'); Description = 'Find entries' }
    bat         = @{ Commands = @('bat', 'bat.exe'); Description = 'Cat with syntax' }
    eza         = @{ Commands = @('eza'); Description = 'Modern ls' }
    zoxide      = @{ Commands = @('zoxide'); Description = 'Smart cd' }
    yazi        = @{ Commands = @('yazi'); Description = 'TUI file manager' }
    spf         = @{ Commands = @('spf', 'superfile'); Description = 'superfile TUI' }
    lazygit     = @{ Commands = @('lazygit'); Description = 'TUI git' }
    lazydocker  = @{ Commands = @('lazydocker'); Description = 'TUI docker' }
    gdu         = @{ Commands = @('gdu', 'gdu_windows_amd64', 'gdu.exe'); Description = 'Disk usage (ncdu-class)' }
    btop        = @{ Commands = @('btop', 'btop4win', 'btop4win.exe'); Description = 'System monitor TUI' }
    nvim        = @{ Commands = @('nvim'); Description = 'Neovim editor' }
    delta       = @{ Commands = @('delta'); Description = 'Git diff pager' }
    glow        = @{ Commands = @('glow'); Description = 'Markdown TUI' }
    gum         = @{ Commands = @('gum'); Description = 'Charm UI primitives' }
    lnav        = @{ Commands = @('lnav'); Description = 'Log file navigator' }
    zellij      = @{ Commands = @('zellij'); Description = 'Terminal multiplexer' }
    oha         = @{ Commands = @('oha'); Description = 'HTTP load generator' }
    bandwhich   = @{ Commands = @('bandwhich'); Description = 'Network utilization TUI' }
    tuistore    = @{ Commands = @('tuistore'); Description = 'TUI app store' }
    fastfetch   = @{ Commands = @('fastfetch'); Description = 'System fetch' }
    pwsh        = @{ Commands = @('pwsh'); Description = 'PowerShell 7' }
}

function Get-DsTool {
    [CmdletBinding()]
    param(
        [string]$Name
    )

    function Resolve-Tool([string]$key, $meta) {
        $found = $null
        foreach ($c in @($meta.Commands)) {
            $cmd = Get-Command $c -ErrorAction SilentlyContinue
            if ($cmd) { $found = $cmd; break }
        }
        [pscustomobject]@{
            Name        = $key
            Description = $meta.Description
            Available   = [bool]$found
            Path        = if ($found) { $found.Source } else { $null }
            Command     = if ($found) { $found.Name } else { $meta.Commands[0] }
        }
    }

    if ($Name) {
        $key = $Name.ToLowerInvariant()
        if (-not $script:DsToolCatalog.Contains($key)) {
            # ad-hoc lookup
            $cmd = Get-Command $Name -ErrorAction SilentlyContinue
            return [pscustomobject]@{
                Name = $Name
                Description = 'ad-hoc'
                Available = [bool]$cmd
                Path = if ($cmd) { $cmd.Source } else { $null }
                Command = $Name
            }
        }
        return Resolve-Tool $key $script:DsToolCatalog[$key]
    }

    foreach ($key in $script:DsToolCatalog.Keys) {
        Resolve-Tool $key $script:DsToolCatalog[$key]
    }
}

function Test-DsTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    [bool](Get-DsTool -Name $Name).Available
}

function Use-DsTool {
    <#
    .SYNOPSIS
      Devuelve el path del tool o avisa si falta (no instala solo).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$Required
    )
    $t = Get-DsTool -Name $Name
    if ($t.Available) { return $t.Path }
    $msg = "Tool '$Name' not found. Install it and reopen the shell."
    if ($Required) { throw $msg }
    Write-DsLog -Level Warn -Module tools -Message $msg
    return $null
}

function Register-DsTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$Commands,
        [string]$Description = ''
    )
    $script:DsToolCatalog[$Name.ToLowerInvariant()] = @{
        Commands = $Commands
        Description = $Description
    }
}

function Invoke-DsToolApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ArgumentList
    )
    $path = Use-DsTool -Name $Name -Required:$false
    if (-not $path) {
        Write-Host "Install '$Name' (winget/scoop) then reopen the shell. See Lennerk docs/aesthetic-tui.md" -ForegroundColor Yellow
        return
    }
    if ($ArgumentList -and $ArgumentList.Count -gt 0) {
        & $path @ArgumentList
    }
    else {
        & $path
    }
}

function Invoke-DsYazi {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name yazi -ArgumentList $ArgumentList
}

function Invoke-DsLazygit {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name lazygit -ArgumentList $ArgumentList
}

function Invoke-DsBtop {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name btop -ArgumentList $ArgumentList
}

function Invoke-DsNvim {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name nvim -ArgumentList $ArgumentList
}

function Invoke-DsLazydocker {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name lazydocker -ArgumentList $ArgumentList
}

function Invoke-DsSuperfile {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name spf -ArgumentList $ArgumentList
}

function Invoke-DsGdu {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    $path = Use-DsTool -Name gdu -Required:$false
    if (-not $path) {
        $winget = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\dundee.gdu*" -Recurse -Filter 'gdu*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($winget) { $path = $winget.FullName }
    }
    if (-not $path) {
        Write-Host "Install gdu (winget install dundee.gdu) then reopen the shell." -ForegroundColor Yellow
        return
    }
    if ($ArgumentList -and $ArgumentList.Count -gt 0) { & $path @ArgumentList }
    else { & $path }
}

function Invoke-DsLnav {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name lnav -ArgumentList $ArgumentList
}

function Invoke-DsGlow {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name glow -ArgumentList $ArgumentList
}

function Invoke-DsZellij {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name zellij -ArgumentList $ArgumentList
}

function Invoke-DsOha {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name oha -ArgumentList $ArgumentList
}

function Invoke-DsBandwhich {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name bandwhich -ArgumentList $ArgumentList
}

function Invoke-DsTuistore {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList)
    Invoke-DsToolApp -Name tuistore -ArgumentList $ArgumentList
}

function Register-DsToolsOnLoad {
    # Soft-link winget portable names into session PATH when missing
    try {
        $extras = @(
            @{ Name = 'gdu'; Pattern = 'dundee.gdu*'; Filter = 'gdu*.exe' }
            @{ Name = 'btop'; Pattern = 'aristocratos.btop4win*'; Filter = 'btop4win.exe' }
        )
        $wingetRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
        foreach ($e in $extras) {
            if (Get-Command $e.Name -ErrorAction SilentlyContinue) { continue }
            $exe = Get-ChildItem (Join-Path $wingetRoot $e.Pattern) -Recurse -Filter $e.Filter -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $exe) { continue }
            $dir = $exe.DirectoryName
            if ($env:Path -notlike "*$dir*") {
                $env:Path = "$dir;$env:Path"
            }
            if ($e.Name -eq 'btop' -and $exe.Name -eq 'btop4win.exe' -and -not (Get-Command btop -ErrorAction SilentlyContinue)) {
                Set-Alias -Name btop -Value $exe.FullName -Scope Global -Force -ErrorAction SilentlyContinue
            }
            if ($e.Name -eq 'gdu' -and $exe.Name -ne 'gdu.exe' -and -not (Get-Command gdu -ErrorAction SilentlyContinue)) {
                Set-Alias -Name gdu -Value $exe.FullName -Scope Global -Force -ErrorAction SilentlyContinue
            }
        }

        # pip --user Scripts (tuistore, etc.)
        $pyScripts = Get-ChildItem (Join-Path $env:APPDATA 'Python') -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'Scripts' } |
            Where-Object { Test-Path -LiteralPath $_ }
        foreach ($dir in @($pyScripts)) {
            if ($env:Path -notlike "*$dir*") {
                $env:Path = "$dir;$env:Path"
            }
        }
    }
    catch { }

    # zoxide: hook if available
    try {
        if (Get-Command zoxide -ErrorAction SilentlyContinue) {
            Invoke-Expression (& { zoxide init powershell | Out-String })
        }
    }
    catch {
        Write-DsLog -Level Debug -Module tools -Message "zoxide init skipped: $($_.Exception.Message)"
    }

    try {
        $map = @{}
        foreach ($t in Get-DsTool) { $map[$t.Name] = $t.Available }
        Set-DsContext -Properties @{ Tools = $map }
    }
    catch { }
    Write-DsLog -Level Debug -Module tools -Message 'tools ready'
}

Export-ModuleMember -Function @(
    'Get-DsTool',
    'Test-DsTool',
    'Use-DsTool',
    'Register-DsTool',
    'Register-DsToolsOnLoad',
    'Invoke-DsToolApp',
    'Invoke-DsYazi',
    'Invoke-DsLazygit',
    'Invoke-DsBtop',
    'Invoke-DsNvim',
    'Invoke-DsLazydocker',
    'Invoke-DsSuperfile',
    'Invoke-DsGdu',
    'Invoke-DsLnav',
    'Invoke-DsGlow',
    'Invoke-DsZellij',
    'Invoke-DsOha',
    'Invoke-DsBandwhich',
    'Invoke-DsTuistore'
)
