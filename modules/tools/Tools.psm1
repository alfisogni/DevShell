#requires -Version 7.0
# tools — catálogo y ensure suave de CLIs externas.

$script:DsToolCatalog = [ordered]@{
    git  = @{ Commands = @('git');  Description = 'Version control' }
    fzf  = @{ Commands = @('fzf');  Description = 'Fuzzy finder' }
    rg   = @{ Commands = @('rg');   Description = 'ripgrep search' }
    fd   = @{ Commands = @('fd', 'fd.exe'); Description = 'Find entries' }
    bat  = @{ Commands = @('bat', 'bat.exe'); Description = 'Cat with syntax' }
    pwsh = @{ Commands = @('pwsh'); Description = 'PowerShell 7' }
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

function Register-DsToolsOnLoad {
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
    'Register-DsToolsOnLoad'
)
