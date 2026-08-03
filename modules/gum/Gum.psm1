#requires -Version 7.0
# gum — Charm gum wrappers for confirms, choose, input, spin (Lennerk / Catppuccin).

function Test-DsGumAvailable {
    [CmdletBinding()]
    param()
    [bool](Get-Command gum -ErrorAction SilentlyContinue)
}

function Get-DsGumThemeEnv {
    [CmdletBinding()]
    param()
    # Catppuccin Mocha-ish gum theme via env (charm gum respects GUM_* where supported)
    @{
        GUM_CONFIRM_PROMPT_FOREGROUND     = '#a6e3a1'
        GUM_CONFIRM_SELECTED_FOREGROUND   = '#1e1e2e'
        GUM_CONFIRM_SELECTED_BACKGROUND   = '#a6e3a1'
        GUM_CONFIRM_UNSELECTED_FOREGROUND = '#6c7086'
        GUM_CHOOSE_CURSOR_FOREGROUND      = '#a6e3a1'
        GUM_CHOOSE_HEADER_FOREGROUND      = '#89dceb'
        GUM_CHOOSE_ITEM_FOREGROUND        = '#cdd6f4'
        GUM_CHOOSE_SELECTED_FOREGROUND    = '#a6e3a1'
        GUM_INPUT_CURSOR_FOREGROUND       = '#a6e3a1'
        GUM_INPUT_PROMPT_FOREGROUND       = '#89dceb'
        GUM_SPIN_SPINNER_FOREGROUND       = '#a6e3a1'
        GUM_SPIN_TITLE_FOREGROUND         = '#cdd6f4'
    }
}

function Use-DsGumTheme {
    [CmdletBinding()]
    param([scriptblock]$Script)
    $prev = @{}
    $map = Get-DsGumThemeEnv
    foreach ($k in $map.Keys) {
        $prev[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
        [Environment]::SetEnvironmentVariable($k, [string]$map[$k], 'Process')
    }
    try {
        & $Script
    }
    finally {
        foreach ($k in $prev.Keys) {
            [Environment]::SetEnvironmentVariable($k, $prev[$k], 'Process')
        }
    }
}

function Invoke-DsConfirm {
    <#
    .SYNOPSIS
      Confirmación sí/no (gum o Read-Host).
    #>
    [CmdletBinding()]
    param(
        [string]$Message = 'Continue?',
        [switch]$DefaultYes
    )

    if (Test-DsGumAvailable) {
        return Use-DsGumTheme {
            $gumArgs = @('confirm', $Message)
            if ($DefaultYes) { $gumArgs += '--default=true' }
            & gum @gumArgs
            return ($LASTEXITCODE -eq 0)
        }
    }

    $hint = if ($DefaultYes) { 'Y/n' } else { 'y/N' }
    $ans = Read-Host "$Message [$hint]"
    if ([string]::IsNullOrWhiteSpace($ans)) { return [bool]$DefaultYes }
    return $ans -match '^(y|yes|s|si|sí)$'
}

function Invoke-DsGumChoose {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Items,

        [string]$Prompt = 'Choose',

        [switch]$Multi,

        [int]$Height = 12
    )

    if (-not (Test-DsGumAvailable)) { return $null }

    return Use-DsGumTheme {
        $gumArgs = [System.Collections.Generic.List[string]]::new()
        $gumArgs.Add('choose') | Out-Null
        $gumArgs.Add('--header') | Out-Null
        $gumArgs.Add($Prompt) | Out-Null
        $gumArgs.Add("--height=$Height") | Out-Null
        if ($Multi) {
            $gumArgs.Add('--no-limit') | Out-Null
        }
        $out = $Items | & gum @gumArgs
        if ($Multi) { return @($out | Where-Object { $_ }) }
        if ($out) { return [string]$out }
        return $null
    }
}

function Invoke-DsInput {
    [CmdletBinding()]
    param(
        [string]$Prompt = '>',
        [string]$Placeholder = '',
        [string]$Value = '',
        [switch]$Password
    )

    if (Test-DsGumAvailable) {
        return Use-DsGumTheme {
            $gumArgs = [System.Collections.Generic.List[string]]::new()
            $gumArgs.Add('input') | Out-Null
            $gumArgs.Add('--prompt') | Out-Null
            $gumArgs.Add("$Prompt ") | Out-Null
            if ($Placeholder) {
                $gumArgs.Add('--placeholder') | Out-Null
                $gumArgs.Add($Placeholder) | Out-Null
            }
            if ($Value) {
                $gumArgs.Add('--value') | Out-Null
                $gumArgs.Add($Value) | Out-Null
            }
            if ($Password) { $gumArgs.Add('--password') | Out-Null }
            $out = & gum @gumArgs
            if ($null -ne $out) { return [string]$out }
            return $null
        }
    }

    if ($Password) {
        $sec = Read-Host $Prompt -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    return Read-Host $Prompt
}

function Invoke-DsSpin {
    <#
    .SYNOPSIS
      Progress spinner around a scriptblock (gum spin) or plain run.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Script,

        [string]$Title = 'Working…'
    )

    if (Test-DsGumAvailable) {
        $tmp = [IO.Path]::GetTempFileName() + '.ps1'
        try {
            Set-Content -LiteralPath $tmp -Value $Script.ToString() -Encoding utf8
            return Use-DsGumTheme {
                & gum spin --spinner dot --title $Title -- pwsh -NoProfile -File $tmp
            }
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host $Title -ForegroundColor DarkGray
    & $Script
}

function Register-DsGumOnLoad {
    Write-DsLog -Level Debug -Module gum -Message "gum ready (available=$(Test-DsGumAvailable))"
}

Export-ModuleMember -Function @(
    'Test-DsGumAvailable',
    'Invoke-DsConfirm',
    'Invoke-DsGumChoose',
    'Invoke-DsInput',
    'Invoke-DsSpin',
    'Use-DsGumTheme',
    'Register-DsGumOnLoad'
)
